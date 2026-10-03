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
    enum Roles { NameRole = Qt::UserRole + 1, PathRole, IconRole, GroupRole, EjectableRole, DeviceRole, FavoriteRole };

    struct Place {
        QString name, path, icon, group, device;
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

signals:
    void errorOccurred(const QString &message);

private:
    QList<Place> loadFavorites() const;
    QList<Place> loadVolumes() const;
    void saveFavorites(const QList<Place> &favs);

    QList<Place> m_places;
    QFile m_mounts;
    QSocketNotifier *m_notifier = nullptr;
};
