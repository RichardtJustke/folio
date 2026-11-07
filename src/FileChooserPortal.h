#pragma once

#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QVariantMap>

class QQmlEngine;
class QQuickWindow;

// Backend do xdg-desktop-portal para "Abrir" e "Salvar como" (org.freedesktop.impl.portal.FileChooser).
// Roda como "folio --portal", ativado pelo D-Bus. Cada pedido abre uma janela FilePicker.qml;
// a resposta ao D-Bus só é enviada quando a pessoa escolhe ou cancela.
class FileChooserPortal : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.FileChooser")
    Q_PROPERTY(uint version READ version CONSTANT)

public:
    static constexpr const char *kService = "org.freedesktop.impl.portal.desktop.folio";
    explicit FileChooserPortal(QQmlEngine *engine, QObject *parent = nullptr);
    bool registerOnBus();
    uint version() const { return 4; }

    // Abre o seletor sem D-Bus (teste: folio --pick open|save|dir)
    void showLocal(const QString &mode);

public slots:
    Q_SCRIPTABLE uint OpenFile(const QDBusObjectPath &handle, const QString &appId, const QString &parentWindow,
                               const QString &title, const QVariantMap &options, const QDBusMessage &msg,
                               QVariantMap &results);
    Q_SCRIPTABLE uint SaveFile(const QDBusObjectPath &handle, const QString &appId, const QString &parentWindow,
                               const QString &title, const QVariantMap &options, const QDBusMessage &msg,
                               QVariantMap &results);
    Q_SCRIPTABLE uint SaveFiles(const QDBusObjectPath &handle, const QString &appId, const QString &parentWindow,
                                const QString &title, const QVariantMap &options, const QDBusMessage &msg,
                                QVariantMap &results);

private slots:
    void onPickerFinished(bool ok, const QVariant &paths);

private:
    struct Pending {
        QDBusMessage msg;
        QPointer<QQuickWindow> window;
        QString handle;
        bool local = false;
    };
    void start(const QString &mode, const QDBusObjectPath &handle, const QString &title,
               const QVariantMap &options, const QDBusMessage &msg, bool local = false);
    void finish(int id, uint response, const QStringList &paths);
    void cancel(const QString &handle);

    QQmlEngine *m_engine;
    QHash<int, Pending> m_pending;
    int m_next = 0;
    friend class PortalRequest;
};

// org.freedesktop.impl.portal.Request em <handle>: o app pode fechar o diálogo (Close)
class PortalRequest : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.Request")

public:
    PortalRequest(FileChooserPortal *portal, const QString &handle)
        : QObject(portal), m_portal(portal), m_handle(handle) {}

public slots:
    Q_SCRIPTABLE void Close() { m_portal->cancel(m_handle); }

private:
    FileChooserPortal *m_portal;
    QString m_handle;
};
