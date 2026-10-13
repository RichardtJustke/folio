#pragma once

#include <QObject>
#include <QStringList>

// org.freedesktop.FileManager1 no barramento de sessão: é o que navegadores e outros apps
// chamam em "Mostrar na pasta". A primeira instância fica com o nome; as outras entram na fila.
class FileManager1 : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.FileManager1")

public:
    explicit FileManager1(QObject *parent = nullptr);
    void registerOnBus();

public slots:
    Q_SCRIPTABLE void ShowFolders(const QStringList &uris, const QString &startupId);
    Q_SCRIPTABLE void ShowItems(const QStringList &uris, const QString &startupId);
    Q_SCRIPTABLE void ShowItemProperties(const QStringList &uris, const QString &startupId);

signals:
    // folder: pasta a abrir; reveal: item a selecionar nela (vazio = nenhum)
    void openRequested(const QString &folder, const QString &reveal);
    void propertiesRequested(const QStringList &paths);

private:
    static QStringList toPaths(const QStringList &uris);
};
