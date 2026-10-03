#include "FileOps.h"

#include "Config.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QMimeData>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUrl>
#include <QtConcurrent>

namespace {

const QString kGnomeCopied = QStringLiteral("x-special/gnome-copied-files");
constexpr qint64 kChunk = 1 << 20;
constexpr int kMaxUndo = 50;

using Progress = std::function<void(qint64)>; // bytes adicionais concluídos

QString homeTrash()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Trash";
}

// "foto.png" -> "foto (cópia).png", "foto (cópia 2).png", ...
QString uniqueTarget(const QString &dir, const QString &name, bool isDir)
{
    QString target = dir + "/" + name;
    if (!QFileInfo::exists(target) && !QFileInfo(target).isSymLink())
        return target;
    const QFileInfo fi(name);
    const QString base = isDir ? name : fi.completeBaseName();
    const QString ext = (isDir || fi.suffix().isEmpty()) ? QString() : "." + fi.suffix();
    for (int n = 1;; ++n) {
        const QString suffix = n == 1 ? QStringLiteral(" (cópia)") : QStringLiteral(" (cópia %1)").arg(n);
        target = dir + "/" + base + suffix + ext;
        if (!QFileInfo::exists(target) && !QFileInfo(target).isSymLink())
            return target;
    }
}

qint64 treeSize(const QString &path)
{
    const QFileInfo fi(path);
    if (fi.isSymLink() || !fi.isDir())
        return qMax<qint64>(1, fi.size());
    qint64 total = 1;
    QDirIterator it(path, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        const auto f = it.fileInfo();
        total += (f.isDir() && !f.isSymLink()) ? 1 : qMax<qint64>(1, f.size());
    }
    return total;
}

bool copyFile(const QString &src, const QString &dst, FileOps::JobState &state, const Progress &progress, QString &err)
{
    QFile in(src);
    if (!in.open(QIODevice::ReadOnly)) {
        err = QStringLiteral("Não foi possível ler %1").arg(QFileInfo(src).fileName());
        return false;
    }
    QSaveFile out(dst); // escreve em temporário e renomeia no commit
    out.setDirectWriteFallback(true);
    if (!out.open(QIODevice::WriteOnly)) {
        err = QStringLiteral("Não foi possível criar %1").arg(QFileInfo(dst).fileName());
        return false;
    }
    QByteArray buf;
    while (!in.atEnd()) {
        if (state.cancel) {
            out.cancelWriting();
            return false;
        }
        buf = in.read(kChunk);
        if (out.write(buf) != buf.size()) {
            out.cancelWriting();
            err = QStringLiteral("Falha ao gravar %1 (disco cheio?)").arg(QFileInfo(dst).fileName());
            return false;
        }
        progress(buf.size());
    }
    if (in.size() == 0)
        progress(1);
    if (!out.commit()) {
        err = QStringLiteral("Falha ao gravar %1").arg(QFileInfo(dst).fileName());
        return false;
    }
    const QFileInfo fi(src);
    QFile::setPermissions(dst, fi.permissions());
    QFile f(dst);
    if (f.open(QIODevice::Append))
        f.setFileTime(fi.lastModified(), QFileDevice::FileModificationTime);
    return true;
}

bool copyTree(const QString &src, const QString &dst, FileOps::JobState &state, const Progress &progress, QString &err)
{
    if (state.cancel)
        return false;
    const QFileInfo fi(src);
    if (fi.isSymLink()) {
        progress(1);
        if (!QFile::link(fi.symLinkTarget(), dst)) {
            err = QStringLiteral("Falha ao copiar link %1").arg(fi.fileName());
            return false;
        }
        return true;
    }
    if (fi.isDir()) {
        progress(1);
        if (!QDir().mkpath(dst)) {
            err = QStringLiteral("Falha ao criar %1").arg(dst);
            return false;
        }
        const auto children = QDir(src).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
        for (const auto &c : children)
            if (!copyTree(src + "/" + c, dst + "/" + c, state, progress, err))
                return false;
        QFile::setPermissions(dst, fi.permissions());
        return true;
    }
    return copyFile(src, dst, state, progress, err);
}

bool removeTree(const QString &path)
{
    const QFileInfo fi(path);
    if (fi.isDir() && !fi.isSymLink())
        return QDir(path).removeRecursively();
    return QFile::remove(path);
}

bool isInside(const QString &child, const QString &parent)
{
    return child == parent || child.startsWith(parent + "/");
}

bool sameDevice(const QString &a, const QString &b)
{
    return QStorageInfo(a).device() == QStorageInfo(b).device();
}

// mover: rename quando possível; senão copiar + apagar
bool moveOne(const QString &src, const QString &dst, FileOps::JobState &state, const Progress &progress, QString &err)
{
    if (QFile::rename(src, dst)) {
        progress(treeSize(dst));
        return true;
    }
    if (!copyTree(src, dst, state, progress, err)) {
        if (state.cancel)
            removeTree(dst); // descarta cópia parcial; a origem segue intacta
        return false;
    }
    removeTree(src);
    return true;
}

// lê Path= de um .trashinfo
QString trashOriginalPath(const QString &trashedFile)
{
    const QFileInfo fi(trashedFile);
    QFile f(fi.absolutePath() + "/../info/" + fi.fileName() + ".trashinfo");
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    while (!f.atEnd()) {
        const auto line = QString::fromUtf8(f.readLine()).trimmed();
        if (line.startsWith("Path=")) {
            const auto path = QUrl::fromPercentEncoding(line.mid(5).toUtf8());
            if (QDir::isAbsolutePath(path))
                return path;
            // lixeira de topdir ($topdir/.Trash-$uid/files/x): Path é relativo ao topdir
            QDir topdir(fi.absolutePath());
            topdir.cdUp();
            topdir.cdUp();
            return QDir::cleanPath(topdir.absoluteFilePath(path));
        }
    }
    return {};
}

QString trashInfoFor(const QString &trashedFile)
{
    const QFileInfo fi(trashedFile);
    return QDir::cleanPath(fi.absolutePath() + "/../info/" + fi.fileName() + ".trashinfo");
}

}

FileOps::FileOps(QObject *parent) : QObject(parent)
{
    connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &FileOps::canPasteChanged);
}

QString FileOps::startPath() const
{
    const auto args = QCoreApplication::arguments();
    if (args.size() > 1) {
        const auto arg = args.at(1);
        QFileInfo fi(arg.startsWith("file://") ? QUrl(arg).toLocalFile() : Config::expand(arg));
        if (fi.isDir())
            return fi.absoluteFilePath();
        if (fi.exists())
            return fi.absolutePath();
    }
    return QDir::homePath();
}

bool FileOps::canPaste() const
{
    const auto *md = QGuiApplication::clipboard()->mimeData();
    return md && (md->hasUrls() || md->hasFormat(kGnomeCopied));
}

QString FileOps::trashDir() const
{
    return homeTrash() + "/files";
}

QString FileOps::undoLabel() const
{
    if (m_undo.isEmpty())
        return {};
    switch (m_undo.last().kind) {
    case UndoKind::Copy: return QStringLiteral("Desfazer Cópia");
    case UndoKind::Move: return QStringLiteral("Desfazer Movimentação");
    case UndoKind::Rename: return QStringLiteral("Desfazer Renomeação");
    case UndoKind::Trash: return QStringLiteral("Desfazer Mover para a Lixeira");
    case UndoKind::Mkdir: return QStringLiteral("Desfazer Nova Pasta");
    }
    return {};
}

void FileOps::open(const QString &path)
{
    QProcess::startDetached("xdg-open", {path});
}

void FileOps::openTerminal(const QString &dir)
{
    QProcess::startDetached(qEnvironmentVariable("TERMINAL", "kitty"), {}, dir);
}

void FileOps::copy(const QStringList &paths)
{
    setClipboard(paths, false);
}

void FileOps::cut(const QStringList &paths)
{
    setClipboard(paths, true);
}

void FileOps::setClipboard(const QStringList &paths, bool cut)
{
    if (paths.isEmpty())
        return;
    auto *md = new QMimeData;
    QList<QUrl> urls;
    QByteArray gnome = cut ? "cut" : "copy";
    for (const auto &p : paths) {
        const auto u = QUrl::fromLocalFile(p);
        urls.append(u);
        gnome += "\n" + u.toEncoded();
    }
    md->setUrls(urls);
    md->setData(kGnomeCopied, gnome);
    QGuiApplication::clipboard()->setMimeData(md);
}

void FileOps::paste(const QString &destDir)
{
    const auto *md = QGuiApplication::clipboard()->mimeData();
    if (!md)
        return;
    bool cut = false;
    QList<QUrl> urls = md->urls();
    if (md->hasFormat(kGnomeCopied)) {
        auto lines = QString::fromUtf8(md->data(kGnomeCopied)).split('\n', Qt::SkipEmptyParts);
        if (!lines.isEmpty()) {
            cut = lines.takeFirst().trimmed() == "cut";
            urls.clear();
            for (const auto &l : lines)
                urls.append(QUrl(l.trimmed()));
        }
    }
    QStringList sources;
    for (const auto &u : urls)
        if (u.isLocalFile())
            sources.append(u.toLocalFile());
    if (sources.isEmpty())
        return;
    if (cut)
        QGuiApplication::clipboard()->clear(); // mover é uma operação única
    transfer(sources, destDir, cut);
}

void FileOps::dropUrls(const QList<QUrl> &urls, const QString &destDir)
{
    QStringList sources;
    for (const auto &u : urls)
        if (u.isLocalFile() && u.toLocalFile() != destDir)
            sources.append(QDir::cleanPath(u.toLocalFile()));
    if (sources.isEmpty())
        return;
    if (isInside(destDir, trashDir())) {
        trash(sources);
        return;
    }
    // como no Nautilus: mesmo dispositivo move, outro copia; Ctrl força cópia, Shift força mover
    const auto mods = QGuiApplication::queryKeyboardModifiers();
    bool move = sameDevice(sources.first(), destDir);
    if (mods & Qt::ControlModifier)
        move = false;
    else if (mods & Qt::ShiftModifier)
        move = true;
    transfer(sources, destDir, move);
}

int FileOps::askConflict(JobState &state, const QString &name, const QString &destDir, bool isDir)
{
    if (state.applyAll >= 0)
        return state.applyAll;
    QMutexLocker lock(&state.mutex);
    state.answer = -1;
    QMetaObject::invokeMethod(this, [this, name, destDir, isDir] { emit conflict(name, destDir, isDir); }, Qt::QueuedConnection);
    while (state.answer < 0 && !state.cancel)
        state.cond.wait(&state.mutex, 200);
    return state.cancel ? Skip : state.answer;
}

void FileOps::resolveConflict(int choice, bool applyToAll)
{
    if (!m_job)
        return;
    QMutexLocker lock(&m_job->mutex);
    m_job->answer = choice;
    if (applyToAll)
        m_job->applyAll = choice;
    m_job->cond.wakeAll();
}

void FileOps::cancel()
{
    if (!m_job)
        return;
    m_job->cancel = true;
    m_job->cond.wakeAll();
}

void FileOps::transfer(const QStringList &sources, const QString &destDir, bool move)
{
    if (sources.isEmpty())
        return;
    const auto dest = QDir::cleanPath(destDir);
    Job job = [this, sources, dest, move](JobState &state, auto progress) {
        JobResult res;
        qint64 total = 0, done = 0;
        for (const auto &s : sources)
            total += (move && sameDevice(s, dest)) ? 1 : treeSize(s);
        auto step = [&](qint64 bytes) {
            done += bytes;
            progress(total > 0 ? qMin(1.0, qreal(done) / total) : 1.0);
        };
        for (const auto &src : sources) {
            if (state.cancel)
                break;
            const QFileInfo fi(src);
            const bool isDir = fi.isDir() && !fi.isSymLink();
            QString err;
            if (!fi.exists() && !fi.isSymLink()) {
                res.errors << QStringLiteral("%1 não existe mais").arg(fi.fileName());
                continue;
            }
            if (isDir && isInside(dest, src)) {
                res.errors << QStringLiteral("Não é possível colocar %1 dentro de si mesma").arg(fi.fileName());
                continue;
            }
            if (fi.absolutePath() == dest) {
                if (move)
                    continue; // mover para a mesma pasta: nada a fazer
                // duplicar na mesma pasta: sempre "manter ambos"
                const auto dst = uniqueTarget(dest, fi.fileName(), isDir);
                if (copyTree(src, dst, state, step, err))
                    res.done.append({src, dst});
                else if (!state.cancel)
                    res.errors << err;
                continue;
            }
            QString dst = dest + "/" + fi.fileName();
            if (QFileInfo::exists(dst) || QFileInfo(dst).isSymLink()) {
                const int choice = askConflict(state, fi.fileName(), dest, isDir);
                if (choice == Skip)
                    continue;
                if (choice == KeepBoth) {
                    dst = uniqueTarget(dest, fi.fileName(), isDir);
                } else if (!QFile::moveToTrash(dst)) { // substituir: o antigo vai para a Lixeira
                    res.errors << QStringLiteral("Não foi possível substituir %1").arg(fi.fileName());
                    continue;
                }
            }
            const bool ok = move ? moveOne(src, dst, state, step, err) : copyTree(src, dst, state, step, err);
            if (ok)
                res.done.append({src, dst});
            else if (!state.cancel)
                res.errors << err;
        }
        res.canceled = state.cancel;
        return res;
    };
    runJob(move ? QStringLiteral("Movendo") : QStringLiteral("Copiando"),
           move ? QStringLiteral("Movido") : QStringLiteral("Copiado"), job,
           [this, move](const JobResult &r) { pushUndo(move ? UndoKind::Move : UndoKind::Copy, r.done); });
}

void FileOps::trash(const QStringList &paths)
{
    if (paths.isEmpty())
        return;
    Job job = [paths](JobState &state, auto progress) {
        JobResult res;
        for (int i = 0; i < paths.size() && !state.cancel; ++i) {
            // especificação freedesktop Trash: ~/.local/share/Trash ou $topdir/.Trash-$uid + .trashinfo
            QString inTrash;
            if (QFile::moveToTrash(paths.at(i), &inTrash))
                res.done.append({paths.at(i), inTrash});
            else
                res.errors << QStringLiteral("Falha ao mover %1 para a Lixeira").arg(QFileInfo(paths.at(i)).fileName());
            progress(qreal(i + 1) / paths.size());
        }
        return res;
    };
    runJob(QStringLiteral("Movendo para a Lixeira"), QStringLiteral("Movido para a Lixeira"), job,
           [this](const JobResult &r) { pushUndo(UndoKind::Trash, r.done); });
}

void FileOps::deletePermanently(const QStringList &paths)
{
    if (paths.isEmpty())
        return;
    runJob(QStringLiteral("Excluindo"), QStringLiteral("Excluído permanentemente"), [paths](JobState &state, auto progress) {
        JobResult res;
        for (int i = 0; i < paths.size() && !state.cancel; ++i) {
            const auto &p = paths.at(i);
            if (removeTree(p)) {
                const auto info = trashInfoFor(p);
                if (isInside(p, homeTrash() + "/files"))
                    QFile::remove(info);
            } else {
                res.errors << QStringLiteral("Falha ao excluir %1").arg(QFileInfo(p).fileName());
            }
            progress(qreal(i + 1) / paths.size());
        }
        return res;
    });
}

void FileOps::restoreFromTrash(const QStringList &paths)
{
    if (paths.isEmpty())
        return;
    runJob(QStringLiteral("Restaurando"), QStringLiteral("Restaurado"), [paths](JobState &state, auto progress) {
        JobResult res;
        for (int i = 0; i < paths.size() && !state.cancel; ++i) {
            const auto &p = paths.at(i);
            const auto original = trashOriginalPath(p);
            if (original.isEmpty()) {
                res.errors << QStringLiteral("Local original de %1 desconhecido").arg(QFileInfo(p).fileName());
                continue;
            }
            const QFileInfo target(original);
            QDir().mkpath(target.absolutePath());
            const auto dst = uniqueTarget(target.absolutePath(), target.fileName(), QFileInfo(p).isDir());
            QString err;
            if (moveOne(p, dst, state, [](qint64) {}, err)) {
                QFile::remove(trashInfoFor(p));
                res.done.append({p, dst});
            } else {
                res.errors << QStringLiteral("Falha ao restaurar %1").arg(target.fileName());
            }
            progress(qreal(i + 1) / paths.size());
        }
        return res;
    });
}

void FileOps::emptyTrash()
{
    runJob(QStringLiteral("Esvaziando a Lixeira"), QStringLiteral("Lixeira esvaziada"), [](JobState &, auto progress) {
        JobResult res;
        for (const auto &sub : {"files", "info", "expunged"}) {
            QDir d(homeTrash() + "/" + sub);
            for (const auto &e : d.entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System))
                if (!removeTree(d.filePath(e)))
                    res.errors << QStringLiteral("Falha ao excluir %1").arg(e);
        }
        QFile::remove(homeTrash() + "/directorysizes");
        progress(1);
        return res;
    });
}

QString FileOps::rename(const QString &path, const QString &newName)
{
    const auto name = newName.trimmed();
    const QFileInfo fi(path);
    if (name.isEmpty() || name == fi.fileName())
        return {};
    if (name.contains('/') || name == "." || name == "..") {
        emit errorOccurred(QStringLiteral("Nome inválido"));
        return {};
    }
    const auto target = fi.absolutePath() + "/" + name;
    if (QFileInfo::exists(target)) {
        emit errorOccurred(QStringLiteral("Já existe um item chamado “%1”").arg(name));
        return {};
    }
    if (!QFile::rename(path, target)) {
        emit errorOccurred(QStringLiteral("Não foi possível renomear"));
        return {};
    }
    pushUndo(UndoKind::Rename, {{path, target}});
    return target;
}

QString FileOps::createFolder(const QString &parentDir)
{
    QString target = parentDir + "/Nova pasta";
    for (int n = 2; QFileInfo::exists(target); ++n)
        target = parentDir + QStringLiteral("/Nova pasta %1").arg(n);
    if (!QDir().mkdir(target)) {
        emit errorOccurred(QStringLiteral("Não foi possível criar a pasta"));
        return {};
    }
    pushUndo(UndoKind::Mkdir, {{parentDir, target}});
    return target;
}

void FileOps::pushUndo(UndoKind kind, const Pairs &pairs)
{
    if (pairs.isEmpty())
        return;
    m_undo.append({kind, pairs});
    while (m_undo.size() > kMaxUndo)
        m_undo.removeFirst();
    emit undoChanged();
}

void FileOps::undo()
{
    if (m_undo.isEmpty() || m_busy)
        return;
    const auto entry = m_undo.takeLast();
    emit undoChanged();

    if (entry.kind == UndoKind::Rename) {
        const auto &[from, to] = entry.pairs.first();
        if (QFileInfo::exists(from) || !QFile::rename(to, from))
            emit errorOccurred(QStringLiteral("Não foi possível desfazer a renomeação"));
        else
            emit finished(QStringLiteral("Desfeito"));
        return;
    }
    if (entry.kind == UndoKind::Mkdir) {
        const auto dir = entry.pairs.first().second;
        if (QDir().rmdir(dir) || QFile::moveToTrash(dir))
            emit finished(QStringLiteral("Desfeito"));
        else
            emit errorOccurred(QStringLiteral("Não foi possível desfazer"));
        return;
    }

    const auto kind = entry.kind;
    const auto pairs = entry.pairs;
    runJob(QStringLiteral("Desfazendo"), QStringLiteral("Desfeito"), [kind, pairs](JobState &state, auto progress) {
        JobResult res;
        for (int i = 0; i < pairs.size() && !state.cancel; ++i) {
            const auto &[from, to] = pairs.at(i);
            QString err;
            switch (kind) {
            case UndoKind::Copy: // cópias vão para a Lixeira (recuperáveis)
                if (!QFile::moveToTrash(to))
                    res.errors << QStringLiteral("Falha ao remover %1").arg(QFileInfo(to).fileName());
                break;
            case UndoKind::Move:
            case UndoKind::Trash:
                if (QFileInfo::exists(from)) {
                    res.errors << QStringLiteral("%1 já existe no local original").arg(QFileInfo(from).fileName());
                    break;
                }
                QDir().mkpath(QFileInfo(from).absolutePath());
                if (!moveOne(to, from, state, [](qint64) {}, err))
                    res.errors << QStringLiteral("Falha ao restaurar %1").arg(QFileInfo(from).fileName());
                else if (kind == UndoKind::Trash)
                    QFile::remove(trashInfoFor(to));
                break;
            default:
                break;
            }
            progress(qreal(i + 1) / pairs.size());
        }
        return res;
    });
}

void FileOps::runJob(const QString &label, const QString &doneMessage, Job job, std::function<void(const JobResult &)> onDone)
{
    if (m_busy) {
        emit errorOccurred(QStringLiteral("Aguarde a operação atual terminar"));
        return;
    }
    m_job = std::make_shared<JobState>();
    setBusy(true, label);
    setProgress(0);

    auto *watcher = new QFutureWatcher<JobResult>(this);
    connect(watcher, &QFutureWatcher<JobResult>::finished, this, [this, watcher, doneMessage, onDone] {
        const auto res = watcher->result();
        watcher->deleteLater();
        m_job.reset();
        setBusy(false);
        if (onDone)
            onDone(res);
        if (res.canceled)
            emit finished(QStringLiteral("Cancelado"));
        else if (res.errors.isEmpty())
            emit finished(doneMessage);
        else
            emit errorOccurred(res.errors.mid(0, 5).join('\n') + (res.errors.size() > 5 ? QStringLiteral("\n…") : QString()));
    });

    QPointer<FileOps> self(this);
    auto report = [self](qreal p) {
        QMetaObject::invokeMethod(qApp, [self, p] { if (self) self->setProgress(p); }, Qt::QueuedConnection);
    };
    auto state = m_job;
    watcher->setFuture(QtConcurrent::run([job, report, state] { return job(*state, report); }));
}

void FileOps::setBusy(bool b, const QString &label)
{
    if (b == m_busy)
        return;
    m_busy = b;
    m_busyLabel = label;
    emit busyChanged();
}

void FileOps::setProgress(qreal p)
{
    m_progress = p;
    emit progressChanged();
}

QString FileOps::uriList(const QStringList &paths) const
{
    QStringList out;
    for (const auto &p : paths)
        out << QString::fromUtf8(QUrl::fromLocalFile(p).toEncoded());
    return out.join("\r\n");
}

QUrl FileOps::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(path);
}

QString FileOps::readText(const QString &path, int maxBytes) const
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    auto data = f.read(maxBytes);
    if (data.contains('\0'))
        return QStringLiteral("(arquivo binário)");
    auto text = QString::fromUtf8(data);
    if (!f.atEnd())
        text += QStringLiteral("\n…");
    return text;
}

QString FileOps::parentDir(const QString &path) const
{
    return QFileInfo(path).absolutePath();
}
