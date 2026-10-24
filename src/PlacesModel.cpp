#include "PlacesModel.h"

#include "CloudDrives.h"
#include "Config.h"

#include <QDir>
#include <algorithm>
#include <QJsonArray>
#include <QProcess>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QRegularExpression>
#include <QUrl>

#include <unistd.h>

namespace {
const QSet<QByteArray> kNetworkFs = {"cifs", "smb3", "nfs", "nfs4", "fuse.sshfs", "sshfs", "fuse.rclone", "davfs"};

QString formatFreeSpace(const QString &path)
{
    const QStorageInfo si(path);
    if (!si.isValid() || !si.isReady())
        return {};
    const qint64 free = si.bytesFree();
    if (free <= 0)
        return {};
    if (free >= 1024LL * 1024 * 1024)
        return QStringLiteral("%1 GB livres").arg(free / (1024LL * 1024 * 1024));
    if (free >= 1024 * 1024)
        return QStringLiteral("%1 MB livres").arg(free / (1024 * 1024));
    return QStringLiteral("%1 KB livres").arg(free / 1024);
}

bool isUserVolume(const QStorageInfo &v)
{
    const auto root = v.rootPath();
    return root.startsWith("/run/media/") || root.startsWith("/media/") || root.startsWith("/mnt/")
        || kNetworkFs.contains(v.fileSystemType());
}
}

PlacesModel::PlacesModel(QObject *parent) : QAbstractListModel(parent), m_mounts("/proc/self/mounts")
{
    // /proc/self/mounts sinaliza POLLPRI quando a tabela de montagem muda
    if (m_mounts.open(QIODevice::ReadOnly)) {
        m_notifier = new QSocketNotifier(m_mounts.handle(), QSocketNotifier::Exception, this);
        connect(m_notifier, &QSocketNotifier::activated, this, [this] {
            m_mounts.seek(0);
            m_mounts.readAll();
            refresh();
        });
    }
    refresh();
}

int PlacesModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_places.size();
}

QVariant PlacesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_places.size())
        return {};
    const auto &p = m_places.at(index.row());
    switch (role) {
    case NameRole: return p.name;
    case PathRole: return p.path;
    case IconRole: return p.icon;
    case GroupRole: return p.group;
    case EjectableRole: return p.ejectable;
    case DeviceRole: return p.device;
    case FavoriteRole: return p.favorite;
    case FreeSpaceRole: return p.freeSpace;
    case PlaceTypeRole: return p.type;
    }
    return {};
}

QHash<int, QByteArray> PlacesModel::roleNames() const
{
    return {{NameRole, "name"}, {PathRole, "path"}, {IconRole, "icon"}, {GroupRole, "group"},
            {EjectableRole, "ejectable"}, {DeviceRole, "device"}, {FavoriteRole, "favorite"}, {FreeSpaceRole, "freeSpace"}, {PlaceTypeRole, "placeType"}};
}

void PlacesModel::refresh()
{
    beginResetModel();
    // "Início" (a página com acesso rápido, discos e recentes) fica acima de tudo, sem título de grupo
    m_places = QList<Place>{{QStringLiteral("Início"), QStringLiteral("folio:home"), QStringLiteral("user-home-symbolic"),
                             {}, {}, {}, {}, false, false}}
             + loadStandard() + loadFavorites() + loadVolumes();
    endResetModel();
}

// Pastas principais: sempre presentes; criadas se não existirem.
QList<PlacesModel::Place> PlacesModel::loadStandard() const
{
    struct Std { QStandardPaths::StandardLocation loc; const char *name; const char *icon; const char *folder; };
    const Std defs[] = {
        {QStandardPaths::DesktopLocation, "Área de Trabalho", "user-desktop-symbolic", "Desktop"},
        {QStandardPaths::DownloadLocation, "Downloads", "folder-download-symbolic", "Downloads"},
        {QStandardPaths::DocumentsLocation, "Documentos", "folder-documents-symbolic", "Documents"},
        {QStandardPaths::PicturesLocation, "Imagens", "folder-pictures-symbolic", "Pictures"},
        {QStandardPaths::MoviesLocation, "Vídeos", "folder-videos-symbolic", "Videos"},
    };
    QList<Place> out;
    const QString group = QStringLiteral("Favoritos");
    for (const auto &d : defs) {
        auto path = QStandardPaths::writableLocation(d.loc);
        if (path.isEmpty() || path == QDir::homePath())
            path = QDir::homePath() + "/" + d.folder;
        QDir().mkpath(path);
        out.append({QString::fromUtf8(d.name), QDir::cleanPath(path), QString::fromLatin1(d.icon), group, {}, {}, {}, false, false});
    }
    return out;
}

QList<PlacesModel::Place> PlacesModel::loadFavorites() const
{
    QList<Place> out;
    const auto standard = loadStandard();
    const auto arr = Config::load().value("favorites").toArray();
    for (const auto &v : arr) {
        const auto o = v.toObject();
        const auto path = QDir::cleanPath(Config::expand(o.value("path").toString()));
        const bool dup = std::any_of(standard.begin(), standard.end(), [&](const Place &s) { return s.path == path; });
        if (dup)
            continue;
        auto name = o.value("name").toString();
        if (name.isEmpty())
            name = QFileInfo(path).fileName();
        out.append({name, path, o.value("icon").toString("folder-symbolic"), QStringLiteral("Favoritos"), {}, {}, {}, false, true});
    }
    return out;
}

QList<PlacesModel::Place> PlacesModel::loadVolumes() const
{
    const QString group = QStringLiteral("Locais");
    QList<Place> out;
    const QString fav = QStringLiteral("Favoritos");
    const auto trash = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Trash/files";
    QDir().mkpath(trash);
    out.append({QStringLiteral("Lixeira"), trash, "user-trash-symbolic", fav, {}, {}, {}, false, false});
    out.append({QStringLiteral("Recentes"), "folio:recent", "document-open-recent-symbolic", fav, {}, {}, {}, false, false});

    out.append({QStringLiteral("Pasta pessoal"), QDir::homePath(), "user-home-symbolic", group, {}, formatFreeSpace(QDir::homePath()), {}, false, false});
    out.append({QStringLiteral("Computador"), "/", "computer-symbolic,drive-harddisk-symbolic", group, {}, formatFreeSpace("/"), {}, false, false});

    const auto cloudRoot = CloudDrives::mountRoot() + "/";
    for (const auto &v : QStorageInfo::mountedVolumes()) {
        if (!v.isValid() || !v.isReady() || !isUserVolume(v) || v.rootPath().startsWith(cloudRoot)) // nuvens: grupo próprio
            continue;
        const bool net = kNetworkFs.contains(v.fileSystemType());
        const bool removable = v.rootPath().startsWith("/run/media/") || v.rootPath().startsWith("/media/");
        auto name = v.displayName();
        if (name.isEmpty() || name == v.rootPath())
            name = QFileInfo(v.rootPath()).fileName();
        out.append({name, v.rootPath(),
                    net ? "folder-remote-symbolic" : removable ? "drive-removable-media-symbolic" : "drive-harddisk-symbolic",
                    group, QString::fromLocal8Bit(v.device()), formatFreeSpace(v.rootPath()), {}, removable, false});
    }

    out.append({QStringLiteral("Rede"), QStringLiteral("folio:network"),
                "network-workgroup-symbolic,folder-remote-symbolic", group, {}, {}, {}, false, false});

    out += loadCloud();

    // Smart folders (buscas salvas)
    const QString smartGroup = QStringLiteral("Smart");
    const auto cfg = Config::load();
    const auto arr = cfg.value("smartFolders").toArray();
    for (const auto &v : arr) {
        const auto o = v.toObject();
        out.append({o.value("name").toString(), QStringLiteral("folio:smart:") + o.value("query").toString(),
                    o.value("icon").toString("search-symbolic"), smartGroup, {}, {}, {}, false, false});
    }
    return out;
}

bool PlacesModel::isFavorite(const QString &path) const
{
    for (const auto &p : m_places)
        if (p.path == path && p.group == QLatin1String("Favoritos"))
            return true;
    return false;
}

void PlacesModel::addFavorite(const QString &path)
{
    if (isFavorite(path) || !QFileInfo(path).isDir())
        return;
    auto favs = loadFavorites();
    favs.append({QFileInfo(path).fileName(), path, "folder-symbolic", {}, {}, {}, {}, false, true});
    saveFavorites(favs);
}

void PlacesModel::addFavoriteUrls(const QList<QUrl> &urls)
{
    auto favs = loadFavorites();
    bool changed = false;
    for (const auto &u : urls) {
        const auto path = QDir::cleanPath(u.toLocalFile());
        if (!u.isLocalFile() || !QFileInfo(path).isDir() || isFavorite(path))
            continue;
        favs.append({QFileInfo(path).fileName(), path, "folder-symbolic", {}, {}, {}, {}, false, true});
        changed = true;
    }
    if (changed)
        saveFavorites(favs);
}

void PlacesModel::removeFavorite(const QString &path)
{
    auto favs = loadFavorites();
    favs.removeIf([&](const Place &p) { return p.path == path; });
    saveFavorites(favs);
}

void PlacesModel::saveFavorites(const QList<Place> &favs)
{
    QJsonArray arr;
    for (const auto &f : favs)
        arr.append(QJsonObject{{"name", f.name}, {"path", Config::contract(f.path)}, {"icon", f.icon}});
    auto cfg = Config::load();
    cfg.insert("favorites", arr);
    Config::save(cfg);
    refresh();
}

void PlacesModel::eject(const QString &device)
{
    if (device.startsWith(QLatin1String("rclone:"))) { // nuvem montada pelo rclone
        auto *proc = new QProcess(this);
        connect(proc, &QProcess::finished, this, [this, proc](int code) {
            if (code != 0)
                emit errorOccurred(QString::fromLocal8Bit(proc->readAllStandardError()).trimmed());
            proc->deleteLater();
            refresh();
        });
        proc->start(QStandardPaths::findExecutable("fusermount3").isEmpty() ? "fusermount" : "fusermount3",
                    {"-u", CloudDrives::mountPoint(device.mid(7))});
        return;
    }
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc](int code) {
        if (code != 0)
            emit errorOccurred(QString::fromLocal8Bit(proc->readAllStandardError()).trimmed());
        proc->deleteLater();
    });
    proc->start("udisksctl", {"unmount", "-b", device});
}

QStringList PlacesModel::templates() const
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

QStringList PlacesModel::recentFiles() const
{
    QStringList out;
    const QString xbel = QDir::homePath() + "/.local/share/recently-used.xbel";
    QFile f(xbel);
    if (!f.open(QIODevice::ReadOnly))
        return out;
    auto content = QString::fromUtf8(f.readAll());
    QRegularExpression re("href=\"file://([^\"]+)\"");
    auto it = re.globalMatch(content);
    while (it.hasNext()) {
        auto m = it.next();
        QString path = QUrl::fromPercentEncoding(m.captured(1).toUtf8());
        if (QFileInfo::exists(path))
            out.append(path);
    }
    return out;
}

QVariantList PlacesModel::smartFolders() const
{
    QVariantList out;
    const auto arr = Config::load().value("smartFolders").toArray();
    for (const auto &v : arr) {
        const auto o = v.toObject();
        out.append(QVariantMap{
            {"name", o.value("name").toString()},
            {"query", o.value("query").toString()},
            {"icon", o.value("icon").toString()},
            {"path", QStringLiteral("folio:smart:") + o.value("query").toString()}
        });
    }
    return out;
}

void PlacesModel::addSmartFolder(const QString &name, const QString &query, const QString &icon)
{
    if (name.isEmpty() || query.isEmpty())
        return;
    auto cfg = Config::load();
    auto arr = cfg.value("smartFolders").toArray();
    for (const auto &v : arr) {
        if (v.toObject().value("query").toString() == query)
            return;
    }
    arr.append(QJsonObject{{"name", name}, {"query", query}, {"icon", icon}});
    cfg.insert("smartFolders", arr);
    Config::save(cfg);
    refresh();
}

void PlacesModel::removeSmartFolder(const QString &query)
{
    auto cfg = Config::load();
    auto arr = cfg.value("smartFolders").toArray();
    for (int i = arr.size() - 1; i >= 0; --i) {
        if (arr.at(i).toObject().value("query").toString() == query)
            arr.removeAt(i);
    }
    cfg.insert("smartFolders", arr);
    Config::save(cfg);
    refresh();
}

QVariantList PlacesModel::drives() const
{
    QVariantList out;
    const auto add = [&](const QString &name, const QString &path, const QString &icon) {
        const QStorageInfo si(path);
        if (!si.isValid() || !si.isReady() || si.bytesTotal() <= 0)
            return;
        out.append(QVariantMap{{"name", name}, {"path", path}, {"icon", icon},
                               {"free", si.bytesAvailable()}, {"total", si.bytesTotal()}});
    };
    add(QStringLiteral("Sistema"), QStringLiteral("/"), QStringLiteral("drive-harddisk-symbolic"));
    // /home em partição própria também conta
    if (QStorageInfo(QDir::homePath()).rootPath() != QStorageInfo(QStringLiteral("/")).rootPath())
        add(QStringLiteral("Pasta pessoal"), QDir::homePath(), QStringLiteral("user-home-symbolic"));
    for (const auto &p : m_places) {
        if (p.type == QLatin1String("volume") || (!p.device.isEmpty() && p.group == QLatin1String("Locais")))
            add(p.name, p.path, p.icon);
    }
    return out;
}

QVariantList PlacesModel::quickAccess() const
{
    QVariantList out;
    const auto trash = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Trash/files";
    for (const auto &p : m_places) {
        if (p.group != QLatin1String("Favoritos") || p.path == trash || p.path.startsWith(QLatin1String("folio:")))
            continue;
        // pastas XDG levam o símbolo delas; favoritos do usuário são pastas comuns
        out.append(QVariantMap{{"name", p.name}, {"path", p.path},
                               {"glyph", p.favorite ? QString() : p.icon}, {"removable", p.favorite}});
    }
    return out;
}

// Nuvem: contas do rclone (montadas sob demanda), montagens do gvfs (contas online) e pastas sincronizadas
QList<PlacesModel::Place> PlacesModel::loadCloud() const
{
    const QString group = QStringLiteral("Nuvem");
    const QString icon = QStringLiteral("weather-overcast-symbolic,folder-remote-symbolic");
    QList<Place> out;
    for (const auto &v : CloudDrives::remotes()) {
        const auto r = v.toMap();
        const auto name = r.value("name").toString();
        const auto mp = CloudDrives::mountPoint(name);
        const bool mounted = CloudDrives::isMounted(mp);
        // montada: o lugar é a pasta de verdade; senão, folio:cloud: pede a montagem
        out.append({name, mounted ? mp : QStringLiteral("folio:cloud:") + name, icon, group,
                    QStringLiteral("rclone:") + name, mounted ? formatFreeSpace(mp) : QString(), QStringLiteral("cloud"), mounted, false});
    }
    QDir gvfs(QStringLiteral("/run/user/%1/gvfs").arg(getuid()));
    for (const auto &e : gvfs.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        const auto n = e.fileName();
        if (!n.startsWith("google-drive:") && !n.startsWith("onedrive:"))
            continue;
        const auto user = QRegularExpression("user=([^,]+)").match(n).captured(1);
        const auto host = QRegularExpression("host=([^,]+)").match(n).captured(1);
        const auto label = n.startsWith("google") ? QStringLiteral("Google Drive") : QStringLiteral("OneDrive");
        out.append({user.isEmpty() ? label : label + " (" + user + (host.isEmpty() ? QString() : "@" + host) + ")",
                    e.absoluteFilePath(), icon, group, {}, {}, QStringLiteral("cloud"), false, false});
    }
    for (const char *dir : {"OneDrive", "Dropbox", "Google Drive", "GoogleDrive", "Nextcloud", "MEGA", "pCloudDrive", "Insync"}) {
        const auto path = QDir::homePath() + "/" + QString::fromUtf8(dir);
        if (QFileInfo(path).isDir())
            out.append({QString::fromUtf8(dir), path, icon, group, {}, {}, QStringLiteral("cloud"), false, false});
    }
    return out;
}
