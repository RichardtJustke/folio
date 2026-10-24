#pragma once

#include <QAbstractListModel>
#include <QFile>
#include <QQmlEngine>
#include <QSocketNotifier>

class PlacesModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum Roles { NameRole = Qt::UserRole + 1, PathRole, IconRole, GroupRole, EjectableRole, DeviceRole, FavoriteRole, FreeSpaceRole, PlaceTypeRole };

    struct Place {
        QString name, path, icon, group, device;
        QString freeSpace; // "42 GB livres"
        QString type; // "volume" | "favorite" | "standard" | "template" | "recent"
        bool ejectable = false;
        bool favorite = false;
    };

    explicit PlacesModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addFavorite(const QString &path);
    Q_INVOKABLE void addFavoriteUrls(const QList<QUrl> &urls);
    Q_INVOKABLE void removeFavorite(const QString &path);
    Q_INVOKABLE bool isFavorite(const QString &path) const;
    Q_INVOKABLE void eject(const QString &device);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QStringList templates() const; // arquivos em ~/Modelos
    Q_INVOKABLE QStringList recentFiles() const; // itens do recently-used.xbel
    Q_INVOKABLE void addSmartFolder(const QString &name, const QString &query, const QString &icon);
    Q_INVOKABLE void removeSmartFolder(const QString &query);
    Q_INVOKABLE QVariantList smartFolders() const;
    Q_INVOKABLE QVariantList quickAccess() const; // pastas fixadas: [{name, path, glyph, removable}]
    Q_INVOKABLE QVariantList drives() const; // [{name, path, icon, free, total}] — sistema + volumes do usuário

signals:
    void errorOccurred(const QString &message);

private:
    QList<Place> loadStandard() const;
    QList<Place> loadFavorites() const;
    QList<Place> loadVolumes() const;
    void saveFavorites(const QList<Place> &favs);

    QList<Place> m_places;
    QFile m_mounts;
    QSocketNotifier *m_notifier = nullptr;
};
