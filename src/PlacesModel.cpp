#include "PlacesModel.h"

#include "Config.h"

#include <QDir>
#include <algorithm>
#include <QJsonArray>
#include <QProcess>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUrl>

namespace {
const QSet<QByteArray> kNetworkFs = {"cifs", "smb3", "nfs", "nfs4", "fuse.sshfs", "sshfs", "fuse.rclone", "davfs"};

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
    }
    return {};
}

QHash<int, QByteArray> PlacesModel::roleNames() const
{
    return {{NameRole, "name"}, {PathRole, "path"}, {IconRole, "icon"}, {GroupRole, "group"},
            {EjectableRole, "ejectable"}, {DeviceRole, "device"}, {FavoriteRole, "favorite"}};
}

void PlacesModel::refresh()
{
    beginResetModel();
    m_places = loadStandard() + loadFavorites() + loadVolumes();
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
        out.append({QString::fromUtf8(d.name), QDir::cleanPath(path), QString::fromLatin1(d.icon), group, {}, false, false});
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
        out.append({name, path, o.value("icon").toString("folder-symbolic"), QStringLiteral("Favoritos"), {}, false, true});
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
    out.append({QStringLiteral("Lixeira"), trash, "user-trash-symbolic", fav, {}, false, false});

    out.append({QStringLiteral("Início"), QDir::homePath(), "user-home-symbolic", group, {}, false, false});
    out.append({QStringLiteral("Computador"), "/", "computer-symbolic,drive-harddisk-symbolic", group, {}, false, false});

    for (const auto &v : QStorageInfo::mountedVolumes()) {
        if (!v.isValid() || !v.isReady() || !isUserVolume(v))
            continue;
        const bool net = kNetworkFs.contains(v.fileSystemType());
        const bool removable = v.rootPath().startsWith("/run/media/") || v.rootPath().startsWith("/media/");
        auto name = v.displayName();
        if (name.isEmpty() || name == v.rootPath())
            name = QFileInfo(v.rootPath()).fileName();
        out.append({name, v.rootPath(),
                    net ? "folder-remote-symbolic" : removable ? "drive-removable-media-symbolic" : "drive-harddisk-symbolic",
                    group, QString::fromLocal8Bit(v.device()), removable, false});
    }

    out.append({QStringLiteral("Rede"), QStringLiteral("folio:network"),
                "network-workgroup-symbolic,folder-remote-symbolic", group, {}, false, false});
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
    favs.append({QFileInfo(path).fileName(), path, "folder-symbolic", {}, {}, false, true});
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
        favs.append({QFileInfo(path).fileName(), path, "folder-symbolic", {}, {}, false, true});
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
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc](int code) {
        if (code != 0)
            emit errorOccurred(QString::fromLocal8Bit(proc->readAllStandardError()).trimmed());
        proc->deleteLater();
    });
    proc->start("udisksctl", {"unmount", "-b", device});
}
