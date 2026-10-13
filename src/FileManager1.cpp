#include "FileManager1.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QFileInfo>
#include <QUrl>

FileManager1::FileManager1(QObject *parent)
    : QObject(parent)
{
}

void FileManager1::registerOnBus()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return;
    bus.registerObject("/org/freedesktop/FileManager1", this, QDBusConnection::ExportScriptableSlots);
    bus.interface()->registerService("org.freedesktop.FileManager1",
                                     QDBusConnectionInterface::QueueService,
                                     QDBusConnectionInterface::DontAllowReplacement);
}

QStringList FileManager1::toPaths(const QStringList &uris)
{
    QStringList out;
    for (const auto &u : uris) {
        const QUrl url(u);
        const auto p = url.isLocalFile() ? url.toLocalFile() : (u.startsWith('/') ? u : QString());
        if (!p.isEmpty() && QFileInfo::exists(p))
            out.append(QFileInfo(p).absoluteFilePath());
    }
    return out;
}

void FileManager1::ShowFolders(const QStringList &uris, const QString &)
{
    for (const auto &p : toPaths(uris))
        emit openRequested(QFileInfo(p).isDir() ? p : QFileInfo(p).absolutePath(), {});
}

void FileManager1::ShowItems(const QStringList &uris, const QString &)
{
    QStringList seen; // uma aba por pasta, mesmo com vários itens dela
    for (const auto &p : toPaths(uris)) {
        const auto dir = QFileInfo(p).absolutePath();
        if (seen.contains(dir))
            continue;
        seen.append(dir);
        emit openRequested(dir, p);
    }
}

void FileManager1::ShowItemProperties(const QStringList &uris, const QString &)
{
    const auto paths = toPaths(uris);
    if (!paths.isEmpty())
        emit propertiesRequested(paths);
}
