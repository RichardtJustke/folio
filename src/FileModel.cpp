#include "FileModel.h"

#include <QRegularExpression>

#include "Config.h"
#include "Thumbnailer.h"

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QFutureWatcher>
#include <QJsonValue>
#include <QMimeDatabase>
#include <QStandardPaths>
#include <QtConcurrent>

namespace {

constexpr int kMaxSearchResults = 5000;

struct Listing {
    QList<FileEntry> entries;
    QString error;
};

DateSection sectionFor(const QDateTime &dt, const QDate &today)
{
    const auto d = dt.date();
    if (d >= today)
        return DateSection::Today;
    if (d == today.addDays(-1))
        return DateSection::Yesterday;
    if (d > today.addDays(-7))
        return DateSection::LastWeek;
    return DateSection::Older;
}

QHash<QString, QString> xdgGlyphs()
{
    QHash<QString, QString> m;
    auto add = [&](QStandardPaths::StandardLocation loc, const QString &icon) {
        const auto p = QStandardPaths::writableLocation(loc);
        if (!p.isEmpty() && p != QDir::homePath())
            m.insert(p, icon);
    };
    add(QStandardPaths::DownloadLocation, "folder-download-symbolic");
    add(QStandardPaths::DocumentsLocation, "folder-documents-symbolic");
    add(QStandardPaths::DesktopLocation, "user-desktop-symbolic");
    add(QStandardPaths::MusicLocation, "folder-music-symbolic");
    add(QStandardPaths::PicturesLocation, "folder-pictures-symbolic");
    add(QStandardPaths::MoviesLocation, "folder-videos-symbolic");
    m.insert(QDir::homePath() + "/Público", "folder-publicshare-symbolic");
    m.insert(QDir::homePath() + "/Modelos", "folder-templates-symbolic");
    return m;
}

QDir::Filters filtersFor(bool showHidden)
{
    QDir::Filters f = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
    if (showHidden)
        f |= QDir::Hidden;
    return f;
}

FileEntry makeEntry(const QFileInfo &fi, QDir::Filters filters, bool countChildren, const QDate &today)
{
    static const QMimeDatabase mimeDb;
    static const auto glyphs = xdgGlyphs();

    FileEntry e;
    e.name = fi.fileName();
    e.path = fi.absoluteFilePath();
    e.location = Config::contract(fi.absolutePath());
    e.isDir = fi.isDir();
    e.isHidden = fi.isHidden();
    e.isSymlink = fi.isSymLink();
    e.modified = fi.lastModified();
    e.section = sectionFor(e.modified, today);
    if (e.isDir) {
        if (countChildren)
            e.itemCount = QDir(e.path).entryList(filters).size();
        e.icon = QStringLiteral("folder");
        e.glyph = glyphs.value(e.path);
        e.typeName = QStringLiteral("Pasta");
        e.mime = QStringLiteral("inode/directory");
        e.preview = QStringLiteral("icon");
    } else {
        e.size = fi.size();
        const auto mime = mimeDb.mimeTypeForFile(fi, QMimeDatabase::MatchExtension);
        e.mime = mime.name();
        e.typeName = mime.comment();
        if (!e.typeName.isEmpty())
            e.typeName[0] = e.typeName[0].toUpper();
        e.icon = mime.iconName() + "," + mime.genericIconName() + ",text-x-generic";
        if (fi.isExecutable() && mime.name() == "application/octet-stream")
            e.icon.prepend("application-x-executable,");
        if (Thumbnailer::canThumbnail(e.mime))
            e.thumb = Thumbnailer::encodeId(e.path) + "/" + QString::number(e.modified.toSecsSinceEpoch());
        if (Thumbnailer::isReadableImage(e.mime))
            e.preview = QStringLiteral("image");
        else if (mime.inherits("text/plain"))
            e.preview = QStringLiteral("text");
        else if (!e.thumb.isEmpty())
            e.preview = QStringLiteral("thumb");
        else
            e.preview = QStringLiteral("icon");
    }
    return e;
}

Listing listDirectory(const QString &path, bool showHidden)
{
    Listing out;
    QDir dir(path);
    if (!dir.exists()) {
        out.error = QStringLiteral("A pasta não existe.");
        return out;
    }
    if (!QFileInfo(path).isReadable()) {
        out.error = QStringLiteral("Sem permissão para ler esta pasta.");
        return out;
    }
    const auto filters = filtersFor(showHidden);
    const auto today = QDate::currentDate();
    const auto infos = dir.entryInfoList(filters, QDir::NoSort);
    out.entries.reserve(infos.size());
    for (const auto &fi : infos)
        out.entries.append(makeEntry(fi, filters, true, today));
    return out;
}

Listing searchTree(const QString &root, const QString &query, bool showHidden, std::shared_ptr<std::atomic_bool> cancel)
{
    Listing out;
    const auto filters = filtersFor(showHidden);
    const auto today = QDate::currentDate();
    QDirIterator it(root, filters, QDirIterator::Subdirectories);
    while (it.hasNext() && !*cancel) {
        it.next();
        const auto fi = it.fileInfo();
        if (!fi.fileName().contains(query, Qt::CaseInsensitive))
            continue;
        out.entries.append(makeEntry(fi, filters, false, today));
        if (out.entries.size() >= kMaxSearchResults) {
            out.error = QStringLiteral("Mostrando os primeiros %1 resultados").arg(kMaxSearchResults);
            break;
        }
    }
    return out;
}

void sortEntries(QList<FileEntry> &entries, const QString &key, bool desc, bool grouped)
{
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    auto three = [](auto a, auto b) { return a < b ? -1 : a > b ? 1 : 0; };
    std::sort(entries.begin(), entries.end(), [&](const FileEntry &a, const FileEntry &b) {
        if (grouped && a.section != b.section)
            return a.section < b.section;
        if (a.isDir != b.isDir)
            return a.isDir;
        int r = 0;
        if (key == "modified")
            r = three(a.modified, b.modified);
        else if (key == "size")
            r = a.isDir ? three(a.itemCount, b.itemCount) : three(a.size, b.size);
        else if (key == "type")
            r = collator.compare(a.typeName, b.typeName);
        if (r == 0)
            r = collator.compare(a.name, b.name);
        return desc ? r > 0 : r < 0;
    });
}

QString trashFilesDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Trash/files";
}

}

FileModel::FileModel(QObject *parent) : QObject(parent), m_cancel(std::make_shared<std::atomic_bool>(false))
{
    const auto cfg = Config::load();
    m_showHidden = cfg.value("showHidden").toBool();
    m_groupByDate = cfg.value("groupByDate").toBool(true);
    m_sortKey = cfg.value("sortKey").toString("name");
    m_sortDesc = cfg.value("sortDescending").toBool(false);
    m_viewMode = cfg.value("viewMode").toString("grid");

    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_debounce, &QTimer::timeout, this, &FileModel::reload);
    m_searchDebounce.setSingleShot(true);
    m_searchDebounce.setInterval(250);
    connect(&m_searchDebounce, &QTimer::timeout, this, &FileModel::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    m_freshTimer.setSingleShot(true);
    m_freshTimer.setInterval(1500);
    connect(&m_freshTimer, &QTimer::timeout, this, [this] { m_fresh.clear(); });
}

FileModel::~FileModel()
{
    *m_cancel = true;
}

void FileModel::persist(const QString &key, const QJsonValue &value)
{
    auto cfg = Config::load();
    cfg.insert(key, value);
    Config::save(cfg);
}

void FileModel::setPath(const QString &path)
{
    const auto clean = QDir::cleanPath(path);
    if (clean == m_path)
        return;
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());
    m_path = clean;
    m_watcher.addPath(m_path);
    m_selected.clear();
    m_current = -1;
    m_anchor = -1;
    m_renamingPath.clear();
    m_pendingSelect.clear();
    if (!m_query.isEmpty()) {
        m_query.clear();
        emit searchChanged();
    }
    emit pathChanged();
    emit currentIndexChanged();
    emit renamingPathChanged();
    bumpSelection();
    reload();
}

QString FileModel::title() const
{
    if (m_path == "/")
        return QStringLiteral("Computador");
    if (m_path == QDir::homePath())
        return qEnvironmentVariable("USER", "Início");
    if (isTrash())
        return QStringLiteral("Lixeira");
    return QFileInfo(m_path).fileName();
}

bool FileModel::isTrash() const
{
    return m_path == trashFilesDir();
}

void FileModel::setShowHidden(bool v)
{
    if (v == m_showHidden)
        return;
    m_showHidden = v;
    persist("showHidden", v);
    emit showHiddenChanged();
    reload();
}

void FileModel::setGroupByDate(bool v)
{
    if (v == m_groupByDate)
        return;
    m_groupByDate = v;
    persist("groupByDate", v);
    emit groupByDateChanged();
    refilter();
}

void FileModel::sortBy(const QString &key)
{
    if (key == m_sortKey) {
        m_sortDesc = !m_sortDesc;
    } else {
        m_sortKey = key;
        m_sortDesc = key == "modified" || key == "size"; // mais recentes/maiores primeiro
    }
    persist("sortKey", m_sortKey);
    persist("sortDescending", m_sortDesc);
    emit sortChanged();
    refilter();
}

void FileModel::setViewMode(const QString &m)
{
    if (m == m_viewMode)
        return;
    m_viewMode = m;
    persist("viewMode", m);
    emit viewModeChanged();
}

void FileModel::setSearchQuery(const QString &q)
{
    if (q == m_query)
        return;
    const bool wasRecursiveSearch = m_recursive && !m_query.isEmpty();
    m_query = q;
    emit searchChanged();
    if (m_recursive && !m_query.isEmpty())
        m_searchDebounce.start();
    else if (wasRecursiveSearch)
        reload(); // volta para a listagem normal da pasta
    else
        refilter();
}

void FileModel::setSearchRecursive(bool v)
{
    if (v == m_recursive)
        return;
    m_recursive = v;
    emit searchChanged();
    if (!m_query.isEmpty())
        reload();
}

void FileModel::setColumns(int c)
{
    c = qMax(1, c);
    if (c == m_columns)
        return;
    m_columns = c;
    emit columnsChanged();
    rebuildRows();
}

void FileModel::setCurrentIndex(int i)
{
    if (i == m_current)
        return;
    m_current = i;
    emit currentIndexChanged();
}

void FileModel::setRenamingPath(const QString &p)
{
    if (p == m_renamingPath)
        return;
    m_renamingPath = p;
    emit renamingPathChanged();
}

void FileModel::reload()
{
    if (m_path.isEmpty())
        return;
    *m_cancel = true;
    m_cancel = std::make_shared<std::atomic_bool>(false);
    const auto gen = ++m_generation;
    if (!m_loading) {
        m_loading = true;
        emit loadingChanged();
    }
    auto *watcher = new QFutureWatcher<Listing>(this);
    connect(watcher, &QFutureWatcher<Listing>::finished, this, [this, watcher, gen] {
        auto res = watcher->result();
        watcher->deleteLater();
        applyEntries(std::move(res.entries), res.error, gen);
    });
    if (m_recursive && !m_query.isEmpty())
        watcher->setFuture(QtConcurrent::run(searchTree, m_path, m_query, m_showHidden, m_cancel));
    else
        watcher->setFuture(QtConcurrent::run(listDirectory, m_path, m_showHidden));
}

void FileModel::applyEntries(QList<FileEntry> entries, const QString &error, quint64 generation)
{
    if (generation != m_generation)
        return; // resultado obsoleto
    m_loading = false;
    emit loadingChanged();

    // itens que surgiram numa pasta já listada (para animar a entrada); busca e primeira listagem não contam
    m_fresh.clear();
    QSet<QString> now;
    for (const auto &e : std::as_const(entries))
        now.insert(e.path);
    if (m_knownDir == m_path && m_query.isEmpty()) {
        int n = 0;
        for (const auto &e : std::as_const(entries))
            if (!m_known.contains(e.path) && n < 24)
                m_fresh.insert(e.path, n++);
    }
    m_known = now;
    m_knownDir = m_query.isEmpty() ? m_path : QString();
    if (!m_fresh.isEmpty())
        m_freshTimer.start();

    m_all = std::move(entries);
    m_error = error;
    refilter();
}

void FileModel::refilter()
{
    const auto currentPath = (m_current >= 0 && m_current < m_entries.size()) ? m_entries.at(m_current).path : QString();

    if (m_query.isEmpty() || m_recursive) {
        m_entries = m_all;
    } else {
        m_entries.clear();
        for (const auto &e : std::as_const(m_all))
            if (e.name.contains(m_query, Qt::CaseInsensitive))
                m_entries.append(e);
    }
    sortEntries(m_entries, m_sortKey, m_sortDesc, m_groupByDate);

    QSet<QString> alive;
    for (const auto &e : std::as_const(m_entries))
        alive.insert(e.path);
    m_selected.intersect(alive);

    m_current = -1;
    for (int i = 0; i < m_entries.size(); ++i) {
        const auto &p = m_entries.at(i).path;
        if (!m_pendingSelect.isEmpty() && p == m_pendingSelect) {
            m_selected = {p};
            m_current = i;
            m_pendingSelect.clear();
            break;
        }
        if (p == currentPath)
            m_current = i;
    }
    m_anchor = m_current;

    ++m_revision;
    rebuildRows();
    emit entriesChanged();
    emit currentIndexChanged();
    bumpSelection();
}

void FileModel::rebuildRows()
{
    m_rows.rebuild(m_entries, m_columns, m_groupByDate);
}

void FileModel::bumpSelection()
{
    ++m_selectionRevision;
    emit selectionChanged();
}

QVariantMap FileModel::entry(int index) const
{
    if (index < 0 || index >= m_entries.size())
        return {};
    return RowModel::entryToMap(m_entries.at(index), index);
}

bool FileModel::isSelected(int index) const
{
    return index >= 0 && index < m_entries.size() && m_selected.contains(m_entries.at(index).path);
}

void FileModel::select(int index, int modifiers)
{
    if (index < 0 || index >= m_entries.size()) {
        clearSelection();
        return;
    }
    const auto &p = m_entries.at(index).path;
    if (modifiers & Qt::ShiftModifier && m_anchor >= 0) {
        if (!(modifiers & Qt::ControlModifier))
            m_selected.clear();
        const int a = qMin(m_anchor, index), b = qMax(m_anchor, index);
        for (int i = a; i <= b; ++i)
            m_selected.insert(m_entries.at(i).path);
    } else if (modifiers & Qt::ControlModifier) {
        if (!m_selected.remove(p))
            m_selected.insert(p);
        m_anchor = index;
    } else {
        m_selected = {p};
        m_anchor = index;
    }
    setCurrentIndex(index);
    bumpSelection();
}

void FileModel::invertSelection()
{
    QSet<QString> next;
    for (const auto &e : std::as_const(m_entries))
        if (!m_selected.contains(e.path))
            next.insert(e.path);
    m_selected = next;
    bumpSelection();
}

int FileModel::selectMatching(const QString &pattern)
{
    const QRegularExpression re(QRegularExpression::wildcardToRegularExpression(pattern.trimmed()),
                                QRegularExpression::CaseInsensitiveOption);
    m_selected.clear();
    for (const auto &e : std::as_const(m_entries))
        if (re.match(e.name).hasMatch())
            m_selected.insert(e.path);
    bumpSelection();
    return m_selected.size();
}

void FileModel::selectAll()
{
    for (const auto &e : std::as_const(m_entries))
        m_selected.insert(e.path);
    bumpSelection();
}

void FileModel::clearSelection()
{
    if (m_selected.isEmpty())
        return;
    m_selected.clear();
    bumpSelection();
}

void FileModel::selectPath(const QString &path)
{
    if (path.isEmpty())
        return;
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).path == path) {
            select(i);
            return;
        }
    }
    m_pendingSelect = path; // seleciona quando aparecer no próximo reload
}

QStringList FileModel::selectedPaths() const
{
    QStringList out;
    for (const auto &e : m_entries) // preserva a ordem de exibição
        if (m_selected.contains(e.path))
            out.append(e.path);
    return out;
}

void FileModel::moveCurrent(int delta, int modifiers)
{
    if (m_entries.isEmpty())
        return;
    const int next = m_current < 0 ? 0 : qBound(0, m_current + delta, int(m_entries.size()) - 1);
    select(next, modifiers & Qt::ShiftModifier);
}

void FileModel::moveRow(int direction, int modifiers)
{
    if (m_current < 0) {
        moveCurrent(0, modifiers);
        return;
    }
    const int target = m_rows.verticalNeighbor(m_current, direction);
    if (target >= 0)
        select(target, modifiers & Qt::ShiftModifier);
}

void FileModel::beginRubberBand(bool additive)
{
    m_bandBase = additive ? m_selected : QSet<QString>();
}

void FileModel::updateRubberBand(qreal x1, qreal y1, qreal x2, qreal y2, qreal headerHeight, qreal rowHeight, qreal cellWidth)
{
    auto sel = m_bandBase;
    int last = -1;
    for (int i : m_rows.entriesInRegion(x1, y1, x2, y2, headerHeight, rowHeight, cellWidth)) {
        const auto &p = m_entries.at(i).path;
        if (m_bandBase.contains(p))
            sel.remove(p); // Ctrl+retângulo inverte
        else
            sel.insert(p);
        last = i;
    }
    if (sel == m_selected)
        return;
    m_selected = sel;
    if (last >= 0) { // sem emitir: evita rolar a vista durante o arraste
        m_current = last;
        m_anchor = last;
    }
    bumpSelection();
}
