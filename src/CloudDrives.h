#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariantList>

// Nuvens pelo rclone (Google Drive, OneDrive, Dropbox…): conectar uma conta (o rclone abre o
// navegador para entrar), montar em ~/.local/share/folio/nuvem/<nome> e desmontar.
class CloudDrives : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool available READ available NOTIFY changed)   // rclone instalado
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString busyLabel READ busyLabel NOTIFY changed)

public:
    explicit CloudDrives(QObject *parent = nullptr);

    bool available() const;
    bool busy() const { return !m_busyLabel.isEmpty(); }
    QString busyLabel() const { return m_busyLabel; }

    static QString mountRoot();                 // ~/.local/share/folio/nuvem
    static QString mountPoint(const QString &remote);
    static bool isMounted(const QString &path); // está em /proc/self/mounts
    static QVariantList remotes();              // [{name, type}] do rclone

    Q_INVOKABLE void recheck() { emit changed(); }
    Q_INVOKABLE void mount(const QString &remote);   // pronto: mounted(remote, path)
    Q_INVOKABLE void unmount(const QString &remote);
    Q_INVOKABLE void addRemote(const QString &name, const QString &type);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void openConfigInTerminal();          // "rclone config" para os outros provedores

signals:
    void changed();
    void mounted(const QString &remote, const QString &path);
    void added(const QString &remote);
    void remotesChanged();
    void message(const QString &text, bool error);

private:
    void setBusy(const QString &label);
    QString m_busyLabel;
    class QProcess *m_proc = nullptr;
};
