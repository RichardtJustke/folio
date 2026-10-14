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

// io.github.richardtjustke.Folio: a primeira instância recebe os pedidos das seguintes
// quando "Janela única" está ligada (Configurações → Comportamento).
class FolioInstance : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "io.github.richardtjustke.Folio")

public:
    static constexpr const char *kService = "io.github.richardtjustke.Folio";
    explicit FolioInstance(FileManager1 *target) : QObject(target), m_target(target) {}
    void registerOnBus();
    // true se repassou para a instância aberta (o processo atual pode sair)
    static bool forward(const QString &folder, const QString &reveal);

public slots:
    Q_SCRIPTABLE void Open(const QString &folder, const QString &reveal);

private:
    FileManager1 *m_target;
};
