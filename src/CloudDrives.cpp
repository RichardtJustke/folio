#include "CloudDrives.h"

#include "Config.h"

#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QTimer>

namespace {
QString lastLine(const QString &out)
{
    const auto lines = out.split('\n', Qt::SkipEmptyParts);
    for (const auto &l : lines)
        if (l.contains("ERROR") || l.contains("Failed") || l.contains("error"))
            return l.section(": ", -1).trimmed();
    return lines.isEmpty() ? QString() : lines.last().trimmed();
}
}

CloudDrives::CloudDrives(QObject *parent) : QObject(parent) {}

bool CloudDrives::available() const
{
    return !QStandardPaths::findExecutable("rclone").isEmpty();
}

QString CloudDrives::mountRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/folio/nuvem";
}

QString CloudDrives::mountPoint(const QString &remote)
{
    return mountRoot() + "/" + remote;
}

bool CloudDrives::isMounted(const QString &path)
{
    QFile f("/proc/self/mounts");
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const auto needle = " " + QString(path).replace(' ', "\\040") + " ";
    return QString::fromLocal8Bit(f.readAll()).contains(needle);
}

QVariantList CloudDrives::remotes()
{
    QVariantList out;
    if (QStandardPaths::findExecutable("rclone").isEmpty())
        return out;
    QProcess p;
    p.start("rclone", {"listremotes", "--long"});
    if (!p.waitForFinished(3000))
        return out;
    // "gdrive:      drive"
    for (const auto &line : QString::fromUtf8(p.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts)) {
        const auto name = line.section(':', 0, 0).trimmed();
        const auto type = line.section(':', 1).trimmed();
        if (!name.isEmpty())
            out.append(QVariantMap{{"name", name}, {"type", type}});
    }
    return out;
}

void CloudDrives::setBusy(const QString &label)
{
    m_busyLabel = label;
    emit changed();
}

void CloudDrives::cancel()
{
    if (m_proc)
        m_proc->kill();
}

void CloudDrives::mount(const QString &remote)
{
    const auto path = mountPoint(remote);
    if (isMounted(path)) {
        emit mounted(remote, path);
        return;
    }
    if (!available()) {
        emit message(tr("O rclone não está instalado"), true);
        return;
    }
    if (m_proc)
        return;
    QDir().mkpath(path);
    setBusy(tr("Montando “%1”").arg(remote));
    m_proc = new QProcess(this);
    m_proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_proc, &QProcess::finished, this, [this, remote, path](int code, QProcess::ExitStatus st) {
        const auto out = QString::fromUtf8(m_proc->readAll());
        m_proc->deleteLater();
        m_proc = nullptr;
        setBusy({});
        // --daemon devolve o controle quando a montagem está pronta
        if (st == QProcess::NormalExit && code == 0 && isMounted(path)) {
            emit mounted(remote, path);
            emit remotesChanged();
        } else {
            emit message(tr("Não foi possível montar “%1”: %2").arg(remote, lastLine(out)), true);
        }
    });
    m_proc->start("rclone", {"mount", remote + ":", path, "--vfs-cache-mode", "full", "--daemon",
                             "--daemon-wait", "30s", "--volname", remote});
}

void CloudDrives::unmount(const QString &remote)
{
    const auto path = mountPoint(remote);
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, remote](int code) {
        if (code != 0)
            emit message(tr("Não foi possível desmontar “%1”: %2").arg(remote, lastLine(QString::fromUtf8(p->readAllStandardError()))), true);
        else
            emit message(tr("“%1” desmontado").arg(remote), false);
        p->deleteLater();
        emit remotesChanged();
    });
    p->start(QStandardPaths::findExecutable("fusermount3").isEmpty() ? "fusermount" : "fusermount3", {"-u", path});
}

void CloudDrives::addRemote(const QString &name, const QString &type)
{
    const auto n = name.trimmed();
    static const QRegularExpression valid("^[A-Za-z0-9_][A-Za-z0-9_. -]*$");
    if (!valid.match(n).hasMatch()) {
        emit message(tr("Use só letras, números, espaço, ponto, - e _ no nome"), true);
        return;
    }
    if (m_proc || !available())
        return;
    setBusy(tr("Entre na sua conta no navegador que abriu…"));
    m_proc = new QProcess(this);
    m_proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_proc, &QProcess::finished, this, [this, n](int code, QProcess::ExitStatus st) {
        const auto out = QString::fromUtf8(m_proc->readAll());
        m_proc->deleteLater();
        m_proc = nullptr;
        setBusy({});
        if (st == QProcess::NormalExit && code == 0) {
            emit added(n);
            emit remotesChanged();
        } else {
            emit message(tr("Não foi possível conectar: %1").arg(lastLine(out)), true);
        }
    });
    // o rclone abre o navegador para o login (OAuth) e espera a volta numa porta local
    m_proc->start("rclone", {"config", "create", n, type});
    QTimer::singleShot(10 * 60 * 1000, m_proc, [this] { if (m_proc) m_proc->kill(); });
}

void CloudDrives::openConfigInTerminal()
{
    auto args = QProcess::splitCommand(Config::terminal());
    if (args.isEmpty()) {
        emit message(tr("Nenhum terminal encontrado — defina um em Configurações → Comportamento"), true);
        return;
    }
    const auto prog = args.takeFirst();
    // xdg-terminal-exec e kitty recebem o comando direto; os outros usam -e
    if (!prog.endsWith("xdg-terminal-exec") && !prog.endsWith("kitty"))
        args << "-e";
    args << "rclone" << "config";
    QProcess::startDetached(prog, args, QDir::homePath());
    emit message(tr("Depois de configurar no terminal, volte e clique em “Verificar de novo”"), false);
}
