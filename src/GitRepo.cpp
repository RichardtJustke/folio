#include "GitRepo.h"

#include <QDir>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QTimer>
#include <QtConcurrent>

namespace {
struct Snapshot {
    QString root, branch, upstream;
    int ahead = 0, behind = 0;
    QStringList branches;
    QHash<QString, QString> status;
};

QProcessEnvironment gitEnv()
{
    auto env = QProcessEnvironment::systemEnvironment();
    env.insert("GIT_TERMINAL_PROMPT", "0");                // nunca pede usuário/senha no terminal
    env.insert("GIT_SSH_COMMAND", "ssh -o BatchMode=yes"); // nem a senha da chave SSH (o agente continua valendo)
    env.insert("LC_ALL", "C");
    return env;
}

QByteArray git(const QString &dir, const QStringList &args, bool *ok = nullptr)
{
    QProcess p;
    p.setProcessEnvironment(gitEnv());
    p.start("git", QStringList{"-C", dir} + args);
    const bool done = p.waitForFinished(5000);
    if (ok)
        *ok = done && p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
    return p.readAllStandardOutput();
}

// sobe até achar .git (pasta ou arquivo, no caso de worktrees/submódulos)
QString findRoot(const QString &path)
{
    QDir d(path);
    while (true) {
        if (QFileInfo::exists(d.filePath(".git")))
            return d.absolutePath();
        if (!d.cdUp())
            return {};
    }
}

Snapshot read(const QString &path)
{
    Snapshot s;
    const auto root = findRoot(path);
    if (root.isEmpty())
        return s;
    bool ok = false;
    const auto out = git(root, {"status", "--porcelain=v1", "-b", "-z", "--untracked-files=normal"}, &ok);
    if (!ok)
        return s;
    s.root = root;
    const auto parts = out.split('\0');
    for (int i = 0; i < parts.size(); ++i) {
        const auto line = QString::fromUtf8(parts.at(i));
        if (line.size() < 3)
            continue;
        if (line.startsWith("## ")) {
            // "## main...origin/main [ahead 1, behind 2]" ou "## No commits yet on main" ou "## HEAD (no branch)"
            auto head = line.mid(3);
            static const QRegularExpression aheadRe("ahead (\\d+)"), behindRe("behind (\\d+)");
            if (auto m = aheadRe.match(head); m.hasMatch())
                s.ahead = m.captured(1).toInt();
            if (auto m = behindRe.match(head); m.hasMatch())
                s.behind = m.captured(1).toInt();
            head = head.section(" [", 0, 0);
            if (head.startsWith("No commits yet on "))
                head = head.mid(18);
            s.branch = head.section("...", 0, 0);
            s.upstream = head.contains("...") ? head.section("...", 1) : QString();
            if (s.branch.startsWith("HEAD"))
                s.branch = QString::fromUtf8(git(root, {"rev-parse", "--short", "HEAD"})).trimmed();
            continue;
        }
        const QChar x = line.at(0), y = line.at(1);
        auto rel = line.mid(3);
        if (x == 'R' || x == 'C')
            ++i; // o nome antigo vem no campo seguinte
        if (rel.endsWith('/'))
            rel.chop(1);
        QString code;
        if (x == 'U' || y == 'U' || (x == 'A' && y == 'A') || (x == 'D' && y == 'D'))
            code = "U";
        else if (x == '?')
            code = "?";
        else if (x == 'D' || y == 'D')
            code = "D";
        else if (x == 'R')
            code = "R";
        else if (x == 'A')
            code = "A";
        else
            code = "M";
        s.status.insert(root + "/" + rel, code);
    }
    for (const auto &b : QString::fromUtf8(git(root, {"branch", "--format=%(refname:short)"})).split('\n', Qt::SkipEmptyParts))
        s.branches.append(b.trimmed());
    return s;
}
}

GitRepo::GitRepo(QObject *parent) : QObject(parent) {}

void GitRepo::setPath(const QString &path)
{
    if (path == m_path)
        return;
    m_path = path;
    emit pathChanged();
    refresh();
}

void GitRepo::setEnabled(bool v)
{
    if (v == m_enabled)
        return;
    m_enabled = v;
    emit pathChanged();
    refresh();
}

void GitRepo::clear()
{
    const bool had = !m_root.isEmpty() || !m_status.isEmpty();
    m_root.clear();
    m_branch.clear();
    m_upstream.clear();
    m_ahead = m_behind = m_changes = 0;
    m_branches.clear();
    m_status.clear();
    m_dirtyDirs.clear();
    if (had) {
        ++m_revision;
        emit stateChanged();
    }
}

void GitRepo::refresh()
{
    const auto gen = ++m_generation;
    // só pastas locais de verdade (nada de folio:, arquivos compactados ou /run/user/.../gvfs)
    if (!m_enabled || m_path.isEmpty() || m_path.startsWith("folio:") || m_path.contains("::") || m_path.contains("/gvfs/")
        || QStandardPaths::findExecutable("git").isEmpty()) {
        clear();
        return;
    }
    auto *watcher = new QFutureWatcher<Snapshot>(this);
    connect(watcher, &QFutureWatcher<Snapshot>::finished, this, [this, watcher, gen] {
        auto s = watcher->result();
        watcher->deleteLater();
        if (gen != m_generation)
            return;
        m_root = s.root;
        m_branch = s.branch;
        m_upstream = s.upstream;
        m_ahead = s.ahead;
        m_behind = s.behind;
        m_branches = s.branches;
        m_status = s.status;
        m_changes = int(m_status.size());
        m_dirtyDirs.clear();
        for (auto it = m_status.cbegin(); it != m_status.cend(); ++it) {
            QString dir = QFileInfo(it.key()).path();
            while (dir.size() > m_root.size() && !m_dirtyDirs.contains(dir)) {
                m_dirtyDirs.insert(dir);
                dir = QFileInfo(dir).path();
            }
        }
        ++m_revision;
        emit stateChanged();
    });
    watcher->setFuture(QtConcurrent::run(read, m_path));
}

QString GitRepo::statusOf(const QString &absPath) const
{
    if (m_root.isEmpty())
        return {};
    if (const auto it = m_status.constFind(absPath); it != m_status.cend())
        return it.value();
    // dentro de uma pasta toda nova (o Git só lista a pasta)
    for (QString dir = QFileInfo(absPath).path(); dir.size() > m_root.size(); dir = QFileInfo(dir).path())
        if (m_status.value(dir) == QLatin1String("?"))
            return QStringLiteral("?");
    return m_dirtyDirs.contains(absPath) ? QStringLiteral("dir") : QString();
}

void GitRepo::run(const QStringList &args, const QString &label, const QString &done)
{
    if (m_root.isEmpty() || m_busy)
        return;
    m_busy = true;
    m_busyLabel = label;
    emit busyChanged();
    auto *p = new QProcess(this);
    p->setProcessEnvironment(gitEnv());
    p->setProcessChannelMode(QProcess::MergedChannels);
    connect(p, &QProcess::finished, this, [this, p, done](int code, QProcess::ExitStatus status) {
        const auto out = QString::fromUtf8(p->readAll()).trimmed();
        p->deleteLater();
        m_busy = false;
        m_busyLabel.clear();
        emit busyChanged();
        if (status == QProcess::NormalExit && code == 0) {
            emit message(done, false);
        } else {
            // a última linha útil do git costuma explicar ("error: …", "fatal: …")
            auto lines = out.split('\n', Qt::SkipEmptyParts);
            QString why = lines.isEmpty() ? QStringLiteral("o git falhou") : lines.last().trimmed();
            for (const auto &l : lines)
                if (l.startsWith("error:") || l.startsWith("fatal:")) { why = l.trimmed(); break; }
            emit message(QStringLiteral("Git: ") + why, true);
        }
        refresh();
    });
    p->start("git", QStringList{"-C", m_root} + args);
    QTimer::singleShot(120000, p, [p] { if (p->state() != QProcess::NotRunning) p->kill(); });
}

void GitRepo::switchBranch(const QString &name)
{
    run({"switch", name}, QStringLiteral("Trocando de branch"), QStringLiteral("Agora em “%1”").arg(name));
}

void GitRepo::createBranch(const QString &name)
{
    const auto n = name.trimmed();
    if (n.isEmpty())
        return;
    run({"switch", "-c", n}, QStringLiteral("Criando branch"), QStringLiteral("Branch “%1” criada").arg(n));
}

void GitRepo::pull()
{
    run({"pull", "--ff-only"}, QStringLiteral("Atualizando (pull)"), QStringLiteral("Repositório atualizado"));
}

void GitRepo::push()
{
    // primeira vez numa branch nova: já cria o upstream
    const QStringList args = m_upstream.isEmpty() ? QStringList{"push", "-u", "origin", m_branch} : QStringList{"push"};
    run(args, QStringLiteral("Enviando (push)"), QStringLiteral("Alterações enviadas"));
}

void GitRepo::fetch()
{
    run({"fetch", "--prune"}, QStringLiteral("Buscando (fetch)"), QStringLiteral("Busca concluída"));
}
