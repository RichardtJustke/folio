#include "FileOps.h"

#include "Config.h"
#include "Tags.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QMimeData>
#include <QMimeDatabase>
#include <QPointer>
#include <QTimer>
#include <QRegularExpression>
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
    connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, [this] {
        readCut();
        emit canPasteChanged();
    });
    readCut();
}

QString FileOps::startPath() const
{
    const auto args = QCoreApplication::arguments();
    if (args.size() > 1) {
        const auto arg = args.at(1);
        if (arg.startsWith(QLatin1String("folio:"))) // páginas do próprio Folio (folio:home, folio:recent)
            return arg;
        QFileInfo fi(arg.startsWith("file://") ? QUrl(arg).toLocalFile() : Config::expand(arg));
        if (fi.isDir())
            return fi.absoluteFilePath();
        if (fi.exists())
            return fi.absolutePath();
    }
    return QStringLiteral("folio:home"); // sem caminho: a página Início
}

QString FileOps::startReveal() const
{
    const auto args = QCoreApplication::arguments();
    if (args.size() < 2)
        return {};
    const auto arg = args.at(1);
    QFileInfo fi(arg.startsWith("file://") ? QUrl(arg).toLocalFile() : Config::expand(arg));
    return fi.exists() && !fi.isDir() ? fi.absoluteFilePath() : QString();
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
    auto args = QProcess::splitCommand(Config::terminal());
    if (args.isEmpty()) {
        emit errorOccurred(tr("Nenhum terminal encontrado — defina um em Configurações → Comportamento"));
        return;
    }
    const auto prog = args.takeFirst();
    QProcess::startDetached(prog, args, dir);
}

void FileOps::copy(const QStringList &paths)
{
    setClipboard(paths, false);
}

void FileOps::cut(const QStringList &paths)
{
    setClipboard(paths, true);
}

// caminhos recortados (x-special/gnome-copied-files começando com "cut"), de qualquer gerenciador
void FileOps::readCut()
{
    m_cutPaths.clear();
    const auto *md = QGuiApplication::clipboard()->mimeData();
    if (!md || !md->hasFormat(kGnomeCopied))
        return;
    auto lines = QString::fromUtf8(md->data(kGnomeCopied)).split('\n', Qt::SkipEmptyParts);
    if (lines.isEmpty() || lines.takeFirst().trimmed() != "cut")
        return;
    for (const auto &l : lines)
        m_cutPaths << QUrl(l.trimmed()).toLocalFile();
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
    // calcula o total de bytes antecipadamente para ETA
    qint64 totalBytes = 0;
    for (const auto &s : sources)
        totalBytes += (move && sameDevice(s, dest)) ? 1 : treeSize(s);
    m_bytesTotal = totalBytes;

    Job job = [this, sources, dest, move, totalBytes](JobState &state, auto progress) {
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

namespace {
// renomeia em duas fases (tudo para nomes temporários, depois para o destino): permite trocas
bool renamePairs(const QList<QPair<QString, QString>> &pairs)
{
    QList<QPair<QString, QString>> staged;
    for (int i = 0; i < pairs.size(); ++i) {
        const auto tmp = QFileInfo(pairs.at(i).first).absolutePath()
                       + QStringLiteral("/.folio-rename-%1-%2").arg(QCoreApplication::applicationPid()).arg(i);
        if (!QFile::rename(pairs.at(i).first, tmp)) {
            for (const auto &[orig, t] : std::as_const(staged)) // volta o que já foi
                QFile::rename(t, orig);
            return false;
        }
        staged.append({pairs.at(i).first, tmp});
    }
    bool ok = true;
    for (int i = 0; i < pairs.size(); ++i)
        ok = QFile::rename(staged.at(i).second, pairs.at(i).second) && ok;
    return ok;
}
}

int FileOps::renameMany(const QStringList &paths, const QStringList &newNames)
{
    if (paths.size() != newNames.size())
        return 0;
    QList<QPair<QString, QString>> pairs;
    QSet<QString> sources(paths.begin(), paths.end());
    QSet<QString> targets;
    for (int i = 0; i < paths.size(); ++i) {
        const auto name = newNames.at(i).trimmed();
        const QFileInfo fi(paths.at(i));
        if (name.isEmpty() || name.contains('/') || name == "." || name == "..") {
            emit errorOccurred(QStringLiteral("Nome inválido: “%1”").arg(name));
            return 0;
        }
        const auto target = fi.absolutePath() + "/" + name;
        if (target == fi.absoluteFilePath())
            continue;
        if (targets.contains(target)) {
            emit errorOccurred(QStringLiteral("Dois itens ficariam com o nome “%1”").arg(name));
            return 0;
        }
        if (QFileInfo::exists(target) && !sources.contains(target)) {
            emit errorOccurred(QStringLiteral("Já existe um item chamado “%1”").arg(name));
            return 0;
        }
        targets.insert(target);
        pairs.append({fi.absoluteFilePath(), target});
    }
    if (pairs.isEmpty())
        return 0;
    if (!renamePairs(pairs)) {
        emit errorOccurred(QStringLiteral("Não foi possível renomear todos os itens"));
        return 0;
    }
    pushUndo(UndoKind::Rename, pairs);
    emit finished(pairs.size() == 1 ? QStringLiteral("1 item renomeado")
                                    : QStringLiteral("%1 itens renomeados").arg(pairs.size()));
    return pairs.size();
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
        QList<QPair<QString, QString>> back;
        QSet<QString> renamed;
        for (const auto &[from, to] : entry.pairs)
            renamed.insert(to);
        bool blocked = false;
        for (const auto &[from, to] : entry.pairs) {
            back.append({to, from});
            blocked = blocked || (QFileInfo::exists(from) && !renamed.contains(from)); // nome antigo ocupado
        }
        if (blocked || !renamePairs(back))
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
    if (b) {
        m_bytesPerSec = 0;
        m_etaSeconds = -1;
        m_bytesDone = 0;
        m_bytesTotal = 0;
        m_lastBytes = 0;
        m_speedTimer.invalidate();
    } else {
        m_bytesPerSec = 0;
        m_etaSeconds = -1;
    }
    emit busyChanged();
    emit speedChanged();
}

void FileOps::setProgress(qreal p)
{
    m_progress = p;
    emit progressChanged();
    // atualiza velocidade a cada ~1s
    if (!m_speedTimer.isValid() || m_speedTimer.hasExpired(1000)) {
        const auto elapsed = m_speedTimer.isValid() ? m_speedTimer.elapsed() : 0;
        if (elapsed > 0 && m_bytesTotal > 0) {
            const qint64 done = qint64(m_progress * m_bytesTotal);
            const qint64 delta = done - m_lastBytes;
            m_bytesPerSec = delta * 1000 / elapsed;
            m_lastBytes = done;
            if (m_bytesPerSec > 0 && m_progress > 0 && m_progress < 1)
                m_etaSeconds = int((m_bytesTotal - done) / m_bytesPerSec);
            else
                m_etaSeconds = -1;
            emit speedChanged();
        }
        m_speedTimer.restart();
    }
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

// ───────────────────────── extras estilo Nautilus ─────────────────────────

namespace {

struct DesktopApp {
    QString id, name, exec, icon;
    QStringList mimes;
};

QList<DesktopApp> scanApps()
{
    QList<DesktopApp> apps;
    QSet<QString> seen;
    const auto dirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    for (const auto &d : dirs) {
        QDirIterator it(d, {"*.desktop"}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const auto file = it.next();
            const auto id = QDir(d).relativeFilePath(file).replace('/', '-');
            if (seen.contains(id))
                continue;
            QFile f(file);
            if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
                continue;
            DesktopApp a;
            a.id = id;
            bool inEntry = false, hidden = false, isApp = true;
            while (!f.atEnd()) {
                const auto line = QString::fromUtf8(f.readLine()).trimmed();
                if (line.startsWith('[')) {
                    inEntry = line == "[Desktop Entry]";
                    continue;
                }
                if (!inEntry)
                    continue;
                const auto eq = line.indexOf('=');
                if (eq < 0)
                    continue;
                const auto k = line.left(eq), v = line.mid(eq + 1);
                if (k == "Name") a.name = v;
                else if (k == "Exec") a.exec = v;
                else if (k == "Icon") a.icon = v;
                else if (k == "MimeType") a.mimes = v.split(';', Qt::SkipEmptyParts);
                else if ((k == "NoDisplay" || k == "Hidden") && v == "true") hidden = true;
                else if (k == "Type" && v != "Application") isApp = false;
            }
            seen.insert(id);
            if (!hidden && isApp && !a.exec.isEmpty() && !a.name.isEmpty())
                apps.append(a);
        }
    }
    return apps;
}

QList<DesktopApp> &appCache()
{
    static QList<DesktopApp> cache = scanApps();
    return cache;
}

const QList<DesktopApp> &apps()
{
    return appCache();
}

const DesktopApp *findApp(const QString &id)
{
    for (const auto &a : apps())
        if (a.id == id)
            return &a;
    return nullptr;
}

// %F/%U recebem todos os arquivos; %f/%u (ou nenhum código) abrem uma instância por arquivo
QList<QStringList> expandExecMany(const QString &exec, const QStringList &paths)
{
    QList<QStringList> runs;
    const bool many = exec.contains("%F") || exec.contains("%U");
    const bool one = exec.contains("%f") || exec.contains("%u");
    if (many || paths.size() <= 1) {
        QStringList out;
        for (auto tok : QProcess::splitCommand(exec)) {
            if (tok == "%F" || tok == "%U" || tok == "%f" || tok == "%u") out << paths;
            else if (tok.size() == 2 && tok[0] == '%' && QStringLiteral("ickdDnNvm").contains(tok[1])) continue;
            else out << tok.replace("%%", "%");
        }
        if (!many && !one)
            out << paths;
        runs << out;
        return runs;
    }
    for (const auto &p : paths)
        runs << expandExecMany(exec, {p});
    return runs;
}

QStringList expandExec(const QString &exec, const QString &path)
{
    QStringList out;
    for (auto tok : QProcess::splitCommand(exec)) {
        if (tok == "%f" || tok == "%F") out << path;
        else if (tok == "%u" || tok == "%U") out << path;
        else if (tok.size() == 2 && tok[0] == '%' && QStringLiteral("ickdDnNvm").contains(tok[1])) continue;
        else out << tok.replace("%%", "%");
    }
    if (!exec.contains("%f") && !exec.contains("%F") && !exec.contains("%u") && !exec.contains("%U"))
        out << path;
    return out;
}

QString permString(QFileDevice::Permissions p)
{
    QString s;
    s += p & QFileDevice::ReadOwner ? 'r' : '-';
    s += p & QFileDevice::WriteOwner ? 'w' : '-';
    s += p & QFileDevice::ExeOwner ? 'x' : '-';
    s += p & QFileDevice::ReadGroup ? 'r' : '-';
    s += p & QFileDevice::WriteGroup ? 'w' : '-';
    s += p & QFileDevice::ExeGroup ? 'x' : '-';
    s += p & QFileDevice::ReadOther ? 'r' : '-';
    s += p & QFileDevice::WriteOther ? 'w' : '-';
    s += p & QFileDevice::ExeOther ? 'x' : '-';
    return s;
}

int permMode(QFileDevice::Permissions p)
{
    int m = 0;
    if (p & QFileDevice::ReadOwner) m |= 0400;
    if (p & QFileDevice::WriteOwner) m |= 0200;
    if (p & QFileDevice::ExeOwner) m |= 0100;
    if (p & QFileDevice::ReadGroup) m |= 040;
    if (p & QFileDevice::WriteGroup) m |= 020;
    if (p & QFileDevice::ExeGroup) m |= 010;
    if (p & QFileDevice::ReadOther) m |= 04;
    if (p & QFileDevice::WriteOther) m |= 02;
    if (p & QFileDevice::ExeOther) m |= 01;
    return m;
}

const QStringList kArchiveSuffixes = {"zip", "tar", "gz", "tgz", "bz2", "xz", "zst", "7z", "rar", "tbz2", "txz"};

}

QString FileOps::createFile(const QString &parentDir)
{
    QString target = parentDir + "/Novo arquivo";
    for (int n = 2; QFileInfo::exists(target); ++n)
        target = parentDir + QStringLiteral("/Novo arquivo %1").arg(n);
    QFile f(target);
    if (!f.open(QIODevice::WriteOnly)) {
        emit errorOccurred(QStringLiteral("Não foi possível criar o arquivo"));
        return {};
    }
    f.close();
    pushUndo(UndoKind::Mkdir, {{parentDir, target}});
    return target;
}

QStringList FileOps::templates() const
{
    QStringList out;
    const auto dir = QDir::homePath() + "/Modelos";
    QDir d(dir);
    if (!d.exists())
        return out;
    for (const auto &e : d.entryInfoList(QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden))
        out.append(e.absoluteFilePath());
    return out;
}

QString FileOps::newFromTemplate(const QString &templatePath, const QString &destDir)
{
    const QFileInfo tfi(templatePath);
    if (!tfi.exists()) {
        emit errorOccurred(QStringLiteral("Modelo não encontrado"));
        return {};
    }
    QString target = destDir + "/" + tfi.fileName();
    for (int n = 2; QFileInfo::exists(target); ++n)
        target = destDir + QStringLiteral("/%1 %2").arg(tfi.completeBaseName()).arg(n) + (tfi.suffix().isEmpty() ? QString() : "." + tfi.suffix());
    if (!QFile::copy(templatePath, target)) {
        emit errorOccurred(QStringLiteral("Não foi possível criar o documento"));
        return {};
    }
    QFile::setPermissions(target, QFile::permissions(target) | QFileDevice::WriteOwner);
    emit finished(QStringLiteral("Documento criado"));
    return target;
}

void FileOps::makeLinks(const QStringList &paths)
{
    int ok = 0;
    for (const auto &p : paths) {
        const QFileInfo fi(p);
        QString target = fi.absolutePath() + "/Link para " + fi.fileName();
        for (int n = 2; QFileInfo::exists(target) || QFileInfo(target).isSymLink(); ++n)
            target = fi.absolutePath() + QStringLiteral("/Link para %1 %2").arg(fi.fileName()).arg(n);
        if (QFile::link(p, target)) {
            ++ok;
            pushUndo(UndoKind::Mkdir, {{fi.absolutePath(), target}});
        } else {
            emit errorOccurred(QStringLiteral("Não foi possível criar link para %1").arg(fi.fileName()));
        }
    }
    if (ok)
        emit finished(ok == 1 ? QStringLiteral("Link criado") : QStringLiteral("%1 links criados").arg(ok));
}

bool FileOps::canZip() const
{
    return !QStandardPaths::findExecutable("zip").isEmpty();
}

bool FileOps::can7z() const
{
    return !sevenZipTool().isEmpty();
}

// 7z (p7zip), 7zz (7-Zip oficial) ou 7za
QString FileOps::sevenZipTool()
{
    for (const char *t : {"7z", "7zz", "7za"})
        if (!QStandardPaths::findExecutable(QString::fromLatin1(t)).isEmpty())
            return QString::fromLatin1(t);
    return {};
}

bool FileOps::isArchive(const QString &path) const
{
    const QFileInfo fi(path);
    return fi.isFile() && kArchiveSuffixes.contains(fi.suffix().toLower());
}

bool FileOps::isArchiveStatic(const QString &path)
{
    const QFileInfo fi(path);
    return fi.isFile() && kArchiveSuffixes.contains(fi.suffix().toLower());
}

void FileOps::compress(const QStringList &paths, const QString &format)
{
    if (paths.isEmpty())
        return;
    const QFileInfo first(paths.first());
    const auto dir = first.absolutePath();
    const bool zip = format == "zip" && canZip();
    const bool seven = format == "7z" && can7z();
    const QString ext = zip ? ".zip" : seven ? ".7z" : ".tar.gz";
    const QString base = paths.size() == 1 ? first.completeBaseName().isEmpty() ? first.fileName() : first.fileName() : QStringLiteral("Arquivo");
    QString out = dir + "/" + base + ext;
    for (int n = 2; QFileInfo::exists(out); ++n)
        out = dir + QStringLiteral("/%1 %2%3").arg(base).arg(n).arg(ext);

    QStringList names;
    for (const auto &p : paths)
        names << QFileInfo(p).fileName();

    auto *proc = new QProcess(this);
    proc->setWorkingDirectory(dir);
    connect(proc, &QProcess::finished, this, [this, proc, out](int code, QProcess::ExitStatus st) {
        proc->deleteLater();
        setBusy(false);
        if (st == QProcess::NormalExit && code == 0) {
            pushUndo(UndoKind::Mkdir, {{QFileInfo(out).absolutePath(), out}});
            emit finished(QStringLiteral("Compactado: %1").arg(QFileInfo(out).fileName()));
        } else {
            QFile::remove(out);
            emit errorOccurred(QStringLiteral("Falha ao compactar"));
        }
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            proc->deleteLater();
            setBusy(false);
            emit errorOccurred(QStringLiteral("Ferramenta de compactação não encontrada"));
        }
    });
    setBusy(true, QStringLiteral("Compactando"));
    if (zip)
        proc->start("zip", QStringList{"-rq", out} + names);
    else if (seven)
        proc->start(sevenZipTool(), QStringList{"a", "-t7z", "-y", out} + names);
    else
        proc->start("tar", QStringList{"-czf", out, "-C", dir} + names);
}

void FileOps::extract(const QString &archive)
{
    const QFileInfo fi(archive);
    QString base = fi.completeBaseName();
    if (base.endsWith(".tar"))
        base.chop(4);
    if (base.isEmpty())
        base = fi.fileName();
    QString dest = fi.absolutePath() + "/" + base;
    for (int n = 2; QFileInfo::exists(dest); ++n)
        dest = fi.absolutePath() + QStringLiteral("/%1 %2").arg(base).arg(n);
    if (!QDir().mkpath(dest)) {
        emit errorOccurred(QStringLiteral("Não foi possível criar a pasta de destino"));
        return;
    }

    QString prog;
    QStringList args;
    const auto suffix = fi.suffix().toLower();
    const auto sevenZip = sevenZipTool();
    if ((suffix == "rar" || suffix == "7z") && !sevenZip.isEmpty()) {
        prog = sevenZip; args = {"x", "-y", "-p", "-o" + dest, archive}; // -p vazio: com senha falha em vez de perguntar
    } else if (suffix == "rar" && !QStandardPaths::findExecutable("unrar").isEmpty()) {
        prog = "unrar"; args = {"x", "-p-", "-o+", archive, dest + "/"};
    } else if (suffix == "rar" && !QStandardPaths::findExecutable("unar").isEmpty()) {
        prog = "unar"; args = {"-q", "-f", "-o", dest, "-D", archive};
    } else if (!QStandardPaths::findExecutable("bsdtar").isEmpty()) {
        prog = "bsdtar"; args = {"-xf", archive, "-C", dest};
    } else if (suffix == "zip" && !QStandardPaths::findExecutable("unzip").isEmpty()) {
        prog = "unzip"; args = {"-q", archive, "-d", dest};
    } else if (suffix == "7z" && !QStandardPaths::findExecutable("7z").isEmpty()) {
        prog = "7z"; args = {"x", "-o" + dest, archive};
    } else {
        prog = "tar"; args = {"-xf", archive, "-C", dest};
    }

    auto *proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(proc, &QProcess::finished, this, [this, proc, dest](int code, QProcess::ExitStatus st) {
        const auto out = QString::fromLocal8Bit(proc->readAll());
        proc->deleteLater();
        setBusy(false);
        if (st == QProcess::NormalExit && code == 0) {
            pushUndo(UndoKind::Mkdir, {{QFileInfo(dest).absolutePath(), dest}});
            emit finished(QStringLiteral("Extraído em “%1”").arg(QFileInfo(dest).fileName()));
        } else {
            QDir(dest).removeRecursively();
            const bool password = out.contains("password", Qt::CaseInsensitive) || out.contains("encrypted", Qt::CaseInsensitive);
            emit errorOccurred(password ? QStringLiteral("Arquivo protegido por senha: extraia pelo terminal ou por outro programa")
                                        : QStringLiteral("Falha ao extrair"));
        }
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc, dest](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            proc->deleteLater();
            setBusy(false);
            QDir(dest).removeRecursively();
            emit errorOccurred(QStringLiteral("Ferramenta de extração não encontrada"));
        }
    });
    setBusy(true, QStringLiteral("Extraindo"));
    proc->start(prog, args);
    proc->closeWriteChannel(); // nenhum programa fica esperando resposta no terminal
}

void FileOps::copyText(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
    emit finished(QStringLiteral("Copiado"));
}

void FileOps::openNewWindow(const QString &path)
{
    QProcess::startDetached(QCoreApplication::applicationFilePath(), {path, "--new-window"});
}

QVariantList FileOps::appsForMime(const QString &mimeName) const
{
    QVariantList out;
    QStringList wanted{mimeName};
    wanted << QMimeDatabase().mimeTypeForName(mimeName).allAncestors();
    for (const auto &a : apps()) {
        bool match = false;
        for (const auto &m : wanted)
            if (a.mimes.contains(m)) {
                match = true;
                break;
            }
        if (match)
            out.append(QVariantMap{{"name", a.name}, {"id", a.id}, {"icon", a.icon}});
    }
    std::sort(out.begin(), out.end(), [](const QVariant &x, const QVariant &y) {
        return x.toMap().value("name").toString().localeAwareCompare(y.toMap().value("name").toString()) < 0;
    });
    return out;
}

QVariantList FileOps::openWithApps(const QString &path) const
{
    return appsForMime(QMimeDatabase().mimeTypeForFile(path).name());
}

QString FileOps::defaultAppId(const QString &mime) const
{
    QProcess p;
    p.start("xdg-mime", {"query", "default", mime});
    if (!p.waitForFinished(1500))
        return {};
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
}

QString FileOps::defaultAppName(const QString &mime) const
{
    const auto id = defaultAppId(mime);
    if (id.isEmpty())
        return {};
    for (const auto &a : apps())
        if (a.id == id)
            return a.name;
    return id;
}

bool FileOps::setDefaultApp(const QString &mime, const QString &appId)
{
    if (QProcess::execute("xdg-mime", {"default", appId, mime}) == 0)
        return true;
    emit errorOccurred(QStringLiteral("Não foi possível definir o aplicativo padrão"));
    return false;
}

void FileOps::openWith(const QString &path, const QString &appId)
{
    openWithMany({path}, appId);
}

void FileOps::openWithMany(const QStringList &paths, const QString &appId)
{
    const auto *a = findApp(appId);
    if (!a) {
        emit errorOccurred(QStringLiteral("Aplicativo não encontrado"));
        return;
    }
    for (auto args : expandExecMany(a->exec, paths)) {
        if (args.isEmpty())
            continue;
        const auto prog = args.takeFirst();
        if (!QProcess::startDetached(prog, args))
            emit errorOccurred(QStringLiteral("Não foi possível abrir “%1”").arg(a->name));
    }
}

QVariantList FileOps::allApps() const
{
    QVariantList out;
    for (const auto &a : apps())
        out.append(QVariantMap{{"name", a.name}, {"id", a.id}, {"icon", a.icon}});
    std::sort(out.begin(), out.end(), [](const QVariant &x, const QVariant &y) {
        return x.toMap().value("name").toString().localeAwareCompare(y.toMap().value("name").toString()) < 0;
    });
    return out;
}

void FileOps::reloadApps()
{
    appCache() = scanApps();
}

// Programa sem atalho (AppImage, binário, script, comando): cria ~/.local/share/applications/folio-<nome>.desktop
QString FileOps::addCustomApp(const QString &name, const QString &command)
{
    auto cmd = command.trimmed();
    const auto title = name.trimmed();
    if (cmd.isEmpty() || title.isEmpty())
        return {};
    // caminho para um arquivo: vira absoluto, entre aspas, e executável (AppImage baixado vem sem +x)
    const QFileInfo fi(Config::expand(cmd.startsWith("file://") ? QUrl(cmd).toLocalFile() : cmd));
    if (fi.isFile()) {
        if (!fi.isExecutable())
            QFile::setPermissions(fi.absoluteFilePath(), QFile(fi.absoluteFilePath()).permissions()
                                  | QFileDevice::ExeOwner | QFileDevice::ExeUser);
        cmd = '"' + fi.absoluteFilePath() + '"';
    }
    if (!cmd.contains(QRegularExpression("%[fFuU]")))
        cmd += " %F";

    auto slug = title.toLower();
    slug.replace(QRegularExpression("[^a-z0-9]+"), "-");
    slug = slug.remove(QRegularExpression("^-+|-+$"));
    if (slug.isEmpty())
        slug = "app";
    const auto dir = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
    QDir().mkpath(dir);
    auto id = "folio-" + slug + ".desktop";
    for (int i = 2; QFile::exists(dir + "/" + id); ++i)
        id = QStringLiteral("folio-%1-%2.desktop").arg(slug).arg(i);

    QSaveFile f(dir + "/" + id);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit errorOccurred(QStringLiteral("Não foi possível criar o atalho do aplicativo"));
        return {};
    }
    f.write(QStringLiteral("[Desktop Entry]\nType=Application\nName=%1\nExec=%2\nIcon=application-x-executable\n"
                           "Terminal=false\nNoDisplay=false\nComment=Criado pelo Folio\n")
                .arg(title, cmd)
                .toUtf8());
    if (!f.commit()) {
        emit errorOccurred(QStringLiteral("Não foi possível criar o atalho do aplicativo"));
        return {};
    }
    QProcess::execute("update-desktop-database", {dir});
    reloadApps();
    return id;
}

QVariantMap FileOps::mimeInfo(const QString &pathOrExt) const
{
    QMimeDatabase db;
    auto s = pathOrExt.trimmed();
    QMimeType m;
    if (s.contains('/') && !s.startsWith('/') && !s.startsWith('~'))
        m = db.mimeTypeForName(s);
    if (!m.isValid()) {
        if (s.startsWith('.')) s.remove(0, 1);
        m = s.contains('/') ? db.mimeTypeForFile(Config::expand(s)) : db.mimeTypeForFile("x." + s, QMimeDatabase::MatchExtension);
    }
    if (!m.isValid() || m.isDefault())
        return {};
    return {{"mime", m.name()}, {"label", m.comment()}, {"suffix", m.preferredSuffix()}};
}

bool FileOps::canRun(const QString &path) const
{
    const QFileInfo fi(path);
    if (!fi.isFile())
        return false;
    if (fi.suffix().compare("AppImage", Qt::CaseInsensitive) == 0)
        return true;
    const auto mime = QMimeDatabase().mimeTypeForFile(fi);
    const bool program = mime.inherits("application/x-executable") || mime.inherits("application/x-sharedlib")
                      || mime.inherits("application/x-pie-executable") || mime.inherits("application/x-shellscript")
                      || mime.inherits("text/x-python") || mime.inherits("application/x-perl");
    return program || (fi.isExecutable() && !mime.inherits("text/plain"));
}

void FileOps::run(const QString &path)
{
    const QFileInfo fi(path);
    if (!fi.isExecutable() && !QFile::setPermissions(path, QFile(path).permissions() | QFileDevice::ExeOwner | QFileDevice::ExeUser)) {
        emit errorOccurred(QStringLiteral("Sem permissão para executar “%1”").arg(fi.fileName()));
        return;
    }
    // scripts rodam no terminal (para ver a saída); programas, soltos
    const auto mime = QMimeDatabase().mimeTypeForFile(fi);
    const bool script = mime.inherits("text/plain") || mime.inherits("application/x-shellscript");
    if (script) {
        auto args = QProcess::splitCommand(Config::terminal());
        if (!args.isEmpty()) {
            const auto prog = args.takeFirst();
            args << "-e" << "sh" << "-c" << "\"$1\"; echo; read -r -p '[Enter para fechar] ' _" << "sh" << fi.absoluteFilePath();
            QProcess::startDetached(prog, args, fi.absolutePath());
            return;
        }
    }
    if (!QProcess::startDetached(fi.absoluteFilePath(), {}, fi.absolutePath()))
        emit errorOccurred(QStringLiteral("Não foi possível executar “%1”").arg(fi.fileName()));
}

// Pasta: outra janela do Folio como root. Arquivo: o app padrão dele como root. Senha pelo polkit.
void FileOps::openAsAdmin(const QString &path)
{
    if (QStandardPaths::findExecutable("pkexec").isEmpty()) {
        emit errorOccurred(QStringLiteral("pkexec não encontrado (instale o polkit)"));
        return;
    }
    QStringList env{"env"};
    for (const char *var : {"DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "XAUTHORITY", "XDG_CURRENT_DESKTOP",
                            "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORM", "XDG_SESSION_TYPE", "DBUS_SESSION_BUS_ADDRESS"})
        if (qEnvironmentVariableIsSet(var))
            env << QStringLiteral("%1=%2").arg(QLatin1String(var), qEnvironmentVariable(var));
    QStringList cmd;
    const QFileInfo fi(path);
    if (fi.isDir()) {
        cmd << QCoreApplication::applicationFilePath() << "--new-window" << fi.absoluteFilePath();
    } else {
        const auto *a = findApp(defaultAppId(QMimeDatabase().mimeTypeForFile(fi).name()));
        if (!a) {
            emit errorOccurred(QStringLiteral("Nenhum aplicativo padrão para este tipo de arquivo"));
            return;
        }
        cmd = expandExec(a->exec, fi.absoluteFilePath());
    }
    if (!QProcess::startDetached("pkexec", env + cmd))
        emit errorOccurred(QStringLiteral("Não foi possível pedir permissão de administrador"));
}

namespace {
// O xdg-desktop-portal só procura .portal em /usr/share/xdg-desktop-portal/portals (ou em
// $XDG_DESKTOP_PORTAL_DIR). Sem o pacote instalado em /usr, o Folio monta uma pasta própria com
// links para os .portal do sistema + o dele e aponta o serviço para ela (drop-in do systemd).
const QString kSysPortals = QStringLiteral("/usr/share/xdg-desktop-portal/portals");

QString portalConfPath()
{
    auto desk = qEnvironmentVariable("XDG_CURRENT_DESKTOP").section(':', 0, 0).toLower();
    if (desk.isEmpty())
        desk = QStringLiteral("hyprland");
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/xdg-desktop-portal/" + desk + "-portals.conf";
}

QString portalDropIn()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/systemd/user/xdg-desktop-portal.service.d/folio.conf";
}

QString dataHome()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
}

bool writeText(const QString &path, const QString &text)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    f.write(text.toUtf8());
    return f.commit();
}

// linhas do [preferred] sem a do FileChooser; começa do arquivo do usuário ou do sistema
QStringList portalConfLines()
{
    QFile f(portalConfPath());
    if (!f.exists())
        f.setFileName("/usr/share/xdg-desktop-portal/" + QFileInfo(portalConfPath()).fileName());
    QStringList lines;
    if (f.open(QIODevice::ReadOnly | QIODevice::Text))
        lines = QString::fromUtf8(f.readAll()).split('\n');
    lines.removeIf([](const QString &l) { return l.trimmed().startsWith("org.freedesktop.impl.portal.FileChooser"); });
    while (!lines.isEmpty() && lines.last().trimmed().isEmpty())
        lines.removeLast();
    if (!lines.contains("[preferred]"))
        lines.prepend("[preferred]");
    return lines;
}
}

bool FileOps::portalEnabled() const
{
    QFile f(portalConfPath());
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;
    return QString::fromUtf8(f.readAll()).contains(QRegularExpression("^org\\.freedesktop\\.impl\\.portal\\.FileChooser\\s*=\\s*folio", QRegularExpression::MultilineOption));
}

bool FileOps::setPortalEnabled(bool on)
{
    const auto service = dataHome() + "/dbus-1/services/org.freedesktop.impl.portal.desktop.folio.service";
    const auto ownDir = dataHome() + "/folio/portals";
    auto lines = portalConfLines();
    bool ok = true;
    if (on) {
        ok &= writeText(service, QStringLiteral("[D-BUS Service]\nName=org.freedesktop.impl.portal.desktop.folio\nExec=%1 --portal\n")
                                     .arg(qEnvironmentVariable("APPIMAGE", QCoreApplication::applicationFilePath()))); // AppImage: o caminho montado muda a cada execução
        if (!QFile::exists(kSysPortals + "/folio.portal")) {
            QDir(ownDir).removeRecursively();
            QDir().mkpath(ownDir);
            for (const auto &name : QDir(kSysPortals).entryList({"*.portal"}, QDir::Files))
                QFile::link(kSysPortals + "/" + name, ownDir + "/" + name);
            ok &= writeText(ownDir + "/folio.portal", QStringLiteral("[portal]\nDBusName=org.freedesktop.impl.portal.desktop.folio\n"
                                                                     "Interfaces=org.freedesktop.impl.portal.FileChooser;\n"));
            ok &= writeText(portalDropIn(), QStringLiteral("# criado pelo Folio (Configurações → Comportamento)\n[Service]\n"
                                                           "Environment=XDG_DESKTOP_PORTAL_DIR=%1\n").arg(ownDir));
        }
        const auto i = lines.indexOf("[preferred]");
        lines.insert(i + 1, "org.freedesktop.impl.portal.FileChooser=folio");
    } else {
        QFile::remove(portalDropIn());
        QDir(ownDir).removeRecursively();
    }
    ok &= writeText(portalConfPath(), lines.join('\n') + '\n');
    // com XDG_DESKTOP_PORTAL_DIR definido, o portal lê o *-portals.conf só dessa pasta
    if (on && QDir(ownDir).exists())
        ok &= writeText(ownDir + "/" + QFileInfo(portalConfPath()).fileName(), lines.join('\n') + '\n');
    QProcess::execute("systemctl", {"--user", "daemon-reload"});
    QProcess::execute("systemctl", {"--user", "restart", "xdg-desktop-portal.service"});
    if (!ok)
        emit errorOccurred(QStringLiteral("Não foi possível configurar o seletor de arquivos"));
    return ok && portalEnabled() == on;
}

QVariantList FileOps::subdirs(const QString &dir, bool hidden) const
{
    QVariantList out;
    QDir d(Config::expand(dir));
    auto filters = QDir::Dirs | QDir::NoDotAndDotDot;
    if (hidden)
        filters |= QDir::Hidden;
    auto names = d.entryList(filters);
    std::sort(names.begin(), names.end(), [](const QString &a, const QString &b) { return a.localeAwareCompare(b) < 0; });
    for (const auto &n : names)
        out.append(QVariantMap{{"name", n}, {"path", d.absoluteFilePath(n)}});
    return out;
}

QVariantList FileOps::quickDirs() const
{
    QVariantList out;
    QStringList seen;
    const auto add = [&](const QString &path, const QString &name, const QString &icon) {
        const auto p = QDir::cleanPath(Config::expand(path));
        if (p.isEmpty() || seen.contains(p) || !QFileInfo(p).isDir())
            return;
        seen << p;
        out.append(QVariantMap{{"name", name}, {"path", p}, {"icon", icon}});
    };
    add(QDir::homePath(), QStringLiteral("Pasta pessoal"), "user-home-symbolic");
    const struct { QStandardPaths::StandardLocation loc; const char *icon; } xdg[] = {
        {QStandardPaths::DesktopLocation, "user-desktop-symbolic"},
        {QStandardPaths::DocumentsLocation, "folder-documents-symbolic"},
        {QStandardPaths::DownloadLocation, "folder-download-symbolic"},
        {QStandardPaths::PicturesLocation, "folder-pictures-symbolic"},
        {QStandardPaths::MusicLocation, "folder-music-symbolic"},
        {QStandardPaths::MoviesLocation, "folder-videos-symbolic"},
    };
    for (const auto &x : xdg) {
        const auto p = QStandardPaths::writableLocation(x.loc);
        if (p != QDir::homePath())
            add(p, QFileInfo(p).fileName(), QString::fromLatin1(x.icon));
    }
    for (const auto &v : Config::load().value("favorites").toArray()) {
        const auto o = v.toObject();
        add(o.value("path").toString(), o.value("name").toString(), o.value("icon").toString("folder-symbolic"));
    }
    return out;
}

// Papel de parede: comando do config (wallpaperCommand, %f = arquivo) > shell quickshell com IPC
// "wallpaper" > awww/swww > hyprpaper > swaybg > KDE > GNOME
void FileOps::setWallpaper(const QString &path)
{
    const auto file = QFileInfo(path).absoluteFilePath();
    const auto has = [](const char *p) { return !QStandardPaths::findExecutable(QString::fromLatin1(p)).isEmpty(); };
    const auto running = [](const QString &name) {
        QProcess p;
        p.start("pgrep", {"-x", name});
        return p.waitForFinished(1000) && p.exitCode() == 0;
    };
    const auto done = [this, file] { emit wallpaperSet(file); };

    const auto custom = Config::load().value("wallpaperCommand").toString();
    if (!custom.isEmpty()) {
        auto args = QProcess::splitCommand(custom);
        for (auto &a : args) a.replace("%f", file);
        if (!args.isEmpty() && QProcess::startDetached(args.takeFirst(), args)) return done();
    }
    // quickshell (ex.: ghost, caelestia): "qs -p <config> ipc call wallpaper setWallpaper all <arquivo> fade"
    {
        QProcess p;
        p.start("pgrep", {"-a", "quickshell"});
        if (p.waitForFinished(1000)) {
            for (const auto &line : QString::fromUtf8(p.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts)) {
                const auto parts = QProcess::splitCommand(line);
                const auto i = parts.indexOf("-p");
                const QStringList where = i > 0 && i + 1 < parts.size() ? QStringList{"-p", parts.at(i + 1)} : QStringList{};
                QProcess ipc;
                ipc.start("quickshell", where + QStringList{"ipc", "call", "wallpaper", "setWallpaper", "all", file, "fade"});
                if (ipc.waitForFinished(3000) && ipc.exitCode() == 0) return done();
            }
        }
    }
    for (const char *tool : {"awww", "swww"})
        if (has(tool) && running(QString::fromLatin1(tool) + "-daemon")
            && QProcess::startDetached(QString::fromLatin1(tool), {"img", file}))
            return done();
    if (has("hyprctl") && running("hyprpaper")) {
        QProcess::execute("hyprctl", {"hyprpaper", "preload", file});
        if (QProcess::execute("hyprctl", {"hyprpaper", "wallpaper", "," + file}) == 0) return done();
    }
    if (has("swaybg")) {
        QProcess::execute("pkill", {"-x", "swaybg"});
        if (QProcess::startDetached("swaybg", {"-m", "fill", "-i", file})) return done();
    }
    if (has("plasma-apply-wallpaperimage") && QProcess::execute("plasma-apply-wallpaperimage", {file}) == 0) return done();
    if (has("gsettings")) {
        const auto uri = QUrl::fromLocalFile(file).toString();
        QProcess::execute("gsettings", {"set", "org.gnome.desktop.background", "picture-uri", uri});
        QProcess::execute("gsettings", {"set", "org.gnome.desktop.background", "picture-uri-dark", uri});
        if (qEnvironmentVariable("XDG_CURRENT_DESKTOP").contains("GNOME", Qt::CaseInsensitive)) return done();
    }
    emit errorOccurred(QStringLiteral("Nenhum programa de papel de parede encontrado — defina \"wallpaperCommand\" no config.json"));
}

QVariantList FileOps::sshHosts() const
{
    QVariantList out;
    QFile f(QDir::homePath() + "/.ssh/config");
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return out;
    while (!f.atEnd()) {
        const auto line = QString::fromUtf8(f.readLine()).trimmed();
        if (!line.startsWith("Host ", Qt::CaseInsensitive))
            continue;
        for (const auto &h : line.mid(5).split(QRegularExpression("\\s+"), Qt::SkipEmptyParts))
            if (!h.contains('*') && !h.contains('?') && !h.startsWith('!'))
                out.append(h);
    }
    return out;
}

bool FileOps::hasNetworkMounts() const
{
    const auto dir = networkDir();
    return !dir.isEmpty() && !QDir(dir).entryList(QDir::AllEntries | QDir::NoDotAndDotDot).isEmpty();
}

void FileOps::connectServer(const QString &targetIn)
{
    QString t = targetIn.trimmed();
    if (t.startsWith("sftp://"))
        t = t.mid(7);
    if (t.isEmpty()) {
        emit errorOccurred(QStringLiteral("Informe o servidor (usuario@host)"));
        return;
    }
    const int slash = t.indexOf('/');
    const QString authority = slash < 0 ? t : t.left(slash);
    const QString remote = slash < 0 ? QString() : t.mid(slash);
    QString hostPart = authority.mid(authority.indexOf('@') + 1);
    const QString host = hostPart.left(hostPart.indexOf(':') < 0 ? hostPart.size() : hostPart.indexOf(':'));

    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc, host, remote](int code, QProcess::ExitStatus) {
        const auto err = QString::fromLocal8Bit(proc->readAllStandardError()).trimmed();
        proc->deleteLater();
        setBusy(false);
        // "já montado" também conta como sucesso
        if (code != 0 && !err.contains("already mounted", Qt::CaseInsensitive)) {
            emit errorOccurred(err.isEmpty() ? QStringLiteral("Falha ao conectar") : err.left(300));
            return;
        }
        const auto gvfs = networkDir();
        for (const auto &e : QDir(gvfs).entryList(QDir::AllEntries | QDir::NoDotAndDotDot)) {
            if (e.startsWith("sftp:") && e.contains("host=" + host)) {
                emit finished(QStringLiteral("Conectado a %1").arg(host));
                emit serverConnected(gvfs + "/" + e + remote);
                return;
            }
        }
        emit errorOccurred(QStringLiteral("Conectado, mas a montagem não apareceu em gvfs"));
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            proc->deleteLater();
            setBusy(false);
            emit errorOccurred(QStringLiteral("Instale gvfs (gio) e gvfs-sftp para conectar via SSH"));
        }
    });
    setBusy(true, QStringLiteral("Conectando"));
    proc->setStandardInputFile(QProcess::nullDevice()); // sem prompt: use chave SSH / ssh-agent
    proc->start("gio", {"mount", "sftp://" + authority + "/"});
    QTimer::singleShot(45000, proc, [proc] { if (proc->state() != QProcess::NotRunning) proc->kill(); });
}

QString FileOps::networkDir() const
{
    const auto dir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/gvfs";
    return QFileInfo(dir).isDir() ? dir : QString();
}

QStringList FileOps::completions(const QString &typed, int limit) const
{
    const auto t = typed.trimmed();
    const int slash = t.lastIndexOf('/');
    if (slash < 0)
        return {};
    const auto typedDir = t.left(slash + 1); // como o usuário escreveu: "~/Doc" -> "~/"
    const auto prefix = t.mid(slash + 1);
    const QDir dir(Config::expand(typedDir));
    if (!dir.exists())
        return {};
    auto filters = QDir::Dirs | QDir::NoDotAndDotDot;
    if (prefix.startsWith('.'))
        filters |= QDir::Hidden;
    QStringList out;
    for (const auto &name : dir.entryList(filters, QDir::Name | QDir::IgnoreCase)) {
        if (!name.startsWith(prefix, Qt::CaseInsensitive))
            continue;
        out.append(typedDir + name + "/");
        if (out.size() >= limit)
            break;
    }
    return out;
}

QString FileOps::resolveDir(const QString &typed) const
{
    auto t = typed.trimmed();
    if (t.isEmpty())
        return {};
    if (t.startsWith("file://"))
        t = QUrl(t).toLocalFile();
    t = Config::expand(t);
    if (QDir::isRelativePath(t))
        return {};
    const QFileInfo fi(QDir::cleanPath(t));
    return fi.isDir() ? fi.absoluteFilePath() : QString();
}

QVariantMap FileOps::properties(const QString &path) const
{
    const QFileInfo fi(path);
    QVariantMap m;
    const auto mime = QMimeDatabase().mimeTypeForFile(path);
    m["name"] = fi.fileName().isEmpty() ? path : fi.fileName();
    m["path"] = fi.absoluteFilePath();
    m["location"] = Config::contract(fi.absolutePath());
    m["type"] = fi.isDir() ? QStringLiteral("Pasta") : mime.comment();
    m["mime"] = fi.isDir() ? QStringLiteral("inode/directory") : mime.name();
    m["isDir"] = fi.isDir() && !fi.isSymLink();
    m["isSymlink"] = fi.isSymLink();
    m["target"] = fi.isSymLink() ? fi.symLinkTarget() : QString();
    m["size"] = fi.size();
    m["modified"] = fi.lastModified();
    m["accessed"] = fi.lastRead();
    m["created"] = fi.birthTime();
    m["owner"] = fi.owner();
    m["group"] = fi.group();
    m["permString"] = permString(fi.permissions());
    m["mode"] = permMode(fi.permissions());
    m["writable"] = fi.isWritable();
    m["hidden"] = fi.isHidden();
    return m;
}

bool FileOps::setPermissions(const QString &path, int mode)
{
    QFileDevice::Permissions p;
    if (mode & 0400) p |= QFileDevice::ReadOwner;
    if (mode & 0200) p |= QFileDevice::WriteOwner;
    if (mode & 0100) p |= QFileDevice::ExeOwner;
    if (mode & 040) p |= QFileDevice::ReadGroup;
    if (mode & 020) p |= QFileDevice::WriteGroup;
    if (mode & 010) p |= QFileDevice::ExeGroup;
    if (mode & 04) p |= QFileDevice::ReadOther;
    if (mode & 02) p |= QFileDevice::WriteOther;
    if (mode & 01) p |= QFileDevice::ExeOther;
    if (QFile::setPermissions(path, p))
        return true;
    emit errorOccurred(QStringLiteral("Não foi possível alterar as permissões"));
    return false;
}

void FileOps::computeSize(const QStringList &paths)
{
    QPointer<FileOps> self(this);
    (void)QtConcurrent::run([self, paths] {
        qint64 bytes = 0;
        int files = 0, folders = 0;
        for (const auto &p : paths) {
            const QFileInfo fi(p);
            if (fi.isSymLink() || !fi.isDir()) {
                bytes += fi.size();
                ++files;
                continue;
            }
            QDirIterator it(p, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System,
                            QDirIterator::Subdirectories);
            while (it.hasNext()) {
                it.next();
                const auto f = it.fileInfo();
                if (f.isDir() && !f.isSymLink()) ++folders;
                else { ++files; bytes += f.size(); }
            }
        }
        QMetaObject::invokeMethod(qApp, [self, bytes, files, folders] {
            if (self)
                emit self->sizeComputed(bytes, files, folders);
        }, Qt::QueuedConnection);
    });
}

bool FileOps::toggleTag(const QStringList &paths, const QString &tag)
{
    bool all = !paths.isEmpty();
    for (const auto &p : paths)
        all = all && Tags::read(p).contains(tag);
    int failed = 0;
    for (const auto &p : paths) {
        auto tags = Tags::read(p);
        tags.removeAll(tag);
        if (!all)
            tags.append(tag);
        if (!Tags::write(p, tags))
            ++failed;
    }
    if (failed)
        emit errorOccurred(tr("Não foi possível etiquetar %n item(ns) (o sistema de arquivos não aceita atributos)", "", failed));
    return !all;
}

QStringList FileOps::tagsOf(const QString &path) const
{
    return Tags::read(path);
}

// ───────────────────────── ações em massa ─────────────────────────

namespace {
// "foto.png" -> "foto.webp"; se existir, "foto 2.webp"…
QString freeOutput(const QString &src, const QString &suffix, const QString &tag = {})
{
    const QFileInfo fi(src);
    const auto base = fi.completeBaseName() + tag;
    auto out = fi.absolutePath() + "/" + base + "." + suffix;
    for (int n = 2; QFileInfo::exists(out); ++n)
        out = fi.absolutePath() + QStringLiteral("/%1 %2.%3").arg(base).arg(n).arg(suffix);
    return out;
}
}

bool FileOps::hasTool(const QString &name) const
{
    return !QStandardPaths::findExecutable(name).isEmpty();
}

// roda um processo por vez; no fim, um aviso com quantos deram certo
void FileOps::runJobs(const QString &label, QList<ToolJob> jobs, int done, int failed)
{
    if (jobs.isEmpty()) {
        setBusy(false);
        if (failed == 0)
            emit finished(QStringLiteral("%1: %2 %3").arg(label).arg(done).arg(done == 1 ? "arquivo" : "arquivos"));
        else
            emit errorOccurred(QStringLiteral("%1: %2 falharam, %3 ok").arg(label).arg(failed).arg(done));
        return;
    }
    const auto job = jobs.takeFirst();
    setBusy(true, label);
    auto *proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(proc, &QProcess::finished, this, [=, this](int code, QProcess::ExitStatus st) {
        proc->deleteLater();
        const bool ok = st == QProcess::NormalExit && code == 0 && QFileInfo::exists(job.out);
        if (ok)
            pushUndo(UndoKind::Mkdir, {{QFileInfo(job.out).absolutePath(), job.out}});
        else
            QFile::remove(job.out);
        runJobs(label, jobs, done + (ok ? 1 : 0), failed + (ok ? 0 : 1));
    });
    connect(proc, &QProcess::errorOccurred, this, [=, this](QProcess::ProcessError e) {
        if (e != QProcess::FailedToStart)
            return;
        proc->deleteLater();
        setBusy(false);
        emit errorOccurred(QStringLiteral("“%1” não está instalado").arg(job.program));
    });
    proc->start(job.program, job.args);
}

void FileOps::convertImages(const QStringList &paths, const QString &format)
{
    QList<ToolJob> jobs;
    for (const auto &p : paths) {
        const auto out = freeOutput(p, format);
        QStringList args{p};
        if (format == "jpg")
            args << "-background" << "white" << "-alpha" << "remove" << "-quality" << "90";
        jobs << ToolJob{"magick", args << out, out};
    }
    runJobs(QStringLiteral("Convertido para .%1").arg(format), jobs);
}

void FileOps::resizeImages(const QStringList &paths, int percent)
{
    QList<ToolJob> jobs;
    for (const auto &p : paths) {
        const auto out = freeOutput(p, QFileInfo(p).suffix(), QStringLiteral(" (%1%)").arg(percent));
        jobs << ToolJob{"magick", {p, "-resize", QString::number(percent) + "%", out}, out};
    }
    runJobs(QStringLiteral("Redimensionado"), jobs);
}

void FileOps::mergePdfs(const QStringList &paths)
{
    if (paths.size() < 2) {
        emit errorOccurred(QStringLiteral("Selecione dois ou mais PDFs"));
        return;
    }
    auto sorted = paths;
    std::sort(sorted.begin(), sorted.end(), [](const QString &a, const QString &b) {
        return QFileInfo(a).fileName().localeAwareCompare(QFileInfo(b).fileName()) < 0;
    });
    const auto out = freeOutput(QFileInfo(sorted.first()).absolutePath() + "/PDFs juntos.pdf", "pdf");
    runJobs(QStringLiteral("PDFs juntados"), {ToolJob{"pdfunite", sorted << out, out}});
}

void FileOps::extractAudio(const QStringList &paths)
{
    QList<ToolJob> jobs;
    for (const auto &p : paths) {
        const auto out = freeOutput(p, "mp3");
        jobs << ToolJob{"ffmpeg", {"-nostdin", "-loglevel", "error", "-i", p, "-vn", "-q:a", "2", out}, out};
    }
    runJobs(QStringLiteral("Áudio extraído"), jobs);
}

void FileOps::convertVideos(const QStringList &paths, const QString &format)
{
    QList<ToolJob> jobs;
    for (const auto &p : paths) {
        const auto out = freeOutput(p, format);
        QStringList args{"-nostdin", "-loglevel", "error", "-i", p};
        if (format == "gif")
            args << "-vf" << "fps=12,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse";
        else if (format == "webm")
            args << "-c:v" << "libvpx-vp9" << "-crf" << "32" << "-b:v" << "0" << "-c:a" << "libopus";
        else
            args << "-c:v" << "libx264" << "-crf" << "23" << "-preset" << "medium" << "-c:a" << "aac";
        jobs << ToolJob{"ffmpeg", args << out, out};
    }
    runJobs(QStringLiteral("Convertido para .%1").arg(format), jobs);
}
