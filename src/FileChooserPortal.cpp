#include "FileChooserPortal.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDir>
#include <QFileInfo>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QUrl>

namespace {

// (sa(us)): nome + regras; tipo 0 = glob ("*.png"), 1 = MIME ("image/png")
QVariantMap readFilter(const QDBusArgument &arg)
{
    QString name;
    QStringList patterns;
    arg.beginStructure();
    arg >> name;
    arg.beginArray();
    while (!arg.atEnd()) {
        uint type = 0;
        QString pattern;
        arg.beginStructure();
        arg >> type >> pattern;
        arg.endStructure();
        patterns << (type == 1 ? "mime:" + pattern : pattern);
    }
    arg.endArray();
    arg.endStructure();
    return {{"name", name}, {"patterns", patterns}};
}

QVariantList readFilters(const QVariant &v)
{
    QVariantList out;
    if (!v.canConvert<QDBusArgument>())
        return out;
    const auto arg = v.value<QDBusArgument>();
    arg.beginArray();
    while (!arg.atEnd())
        out << readFilter(arg);
    arg.endArray();
    return out;
}

// "ay" terminado em \0 (caminhos podem não ser UTF-8)
QString bytesToPath(const QVariant &v)
{
    auto b = v.toByteArray();
    while (b.endsWith('\0'))
        b.chop(1);
    return QFile::decodeName(b);
}

QStringList readByteArrays(const QVariant &v)
{
    QStringList out;
    if (v.canConvert<QDBusArgument>()) {
        const auto arg = v.value<QDBusArgument>();
        arg.beginArray();
        while (!arg.atEnd()) {
            QByteArray b;
            arg >> b;
            out << bytesToPath(b);
        }
        arg.endArray();
    } else {
        for (const auto &x : v.toList())
            out << bytesToPath(x);
    }
    return out;
}

} // namespace

FileChooserPortal::FileChooserPortal(QQmlEngine *engine, QObject *parent) : QObject(parent), m_engine(engine) {}

bool FileChooserPortal::registerOnBus()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.registerObject("/org/freedesktop/portal/desktop", this, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportAllProperties))
        return false;
    return bus.registerService(QString::fromLatin1(kService));
}

uint FileChooserPortal::OpenFile(const QDBusObjectPath &handle, const QString &, const QString &, const QString &title,
                                 const QVariantMap &options, const QDBusMessage &msg, QVariantMap &)
{
    start(options.value("directory").toBool() ? "dir" : "open", handle, title, options, msg);
    return 0;
}

uint FileChooserPortal::SaveFile(const QDBusObjectPath &handle, const QString &, const QString &, const QString &title,
                                 const QVariantMap &options, const QDBusMessage &msg, QVariantMap &)
{
    start("save", handle, title, options, msg);
    return 0;
}

uint FileChooserPortal::SaveFiles(const QDBusObjectPath &handle, const QString &, const QString &, const QString &title,
                                  const QVariantMap &options, const QDBusMessage &msg, QVariantMap &)
{
    start("saveFiles", handle, title, options, msg);
    return 0;
}

void FileChooserPortal::showLocal(const QString &mode)
{
    QVariantMap options;
    if (mode == "save")
        options.insert("current_name", QStringLiteral("sem título.txt"));
    if (mode == "open")
        options.insert("multiple", true);
    start(mode, QDBusObjectPath(), {}, options, {}, true);
}

void FileChooserPortal::start(const QString &mode, const QDBusObjectPath &handle, const QString &title,
                              const QVariantMap &options, const QDBusMessage &msg, bool local)
{
    const int id = ++m_next;
    Pending p;
    p.local = local;
    p.handle = handle.path();
    if (!local) {
        msg.setDelayedReply(true);
        p.msg = msg;
        if (!p.handle.isEmpty())
            QDBusConnection::sessionBus().registerObject(p.handle, new PortalRequest(this, p.handle),
                                                         QDBusConnection::ExportScriptableSlots);
    }

    // pasta inicial: current_folder > pasta do current_file > última usada (lembrada pelo QML) > pessoal
    QString startDir = bytesToPath(options.value("current_folder"));
    QString currentName = options.value("current_name").toString();
    const auto currentFile = bytesToPath(options.value("current_file"));
    if (!currentFile.isEmpty()) {
        const QFileInfo fi(currentFile);
        if (startDir.isEmpty())
            startDir = fi.absolutePath();
        if (currentName.isEmpty())
            currentName = fi.fileName();
    }

    const auto filters = readFilters(options.value("filters"));
    int currentFilter = -1;
    if (options.value("current_filter").canConvert<QDBusArgument>()) {
        const auto cur = readFilter(options.value("current_filter").value<QDBusArgument>());
        for (int i = 0; i < filters.size(); ++i)
            if (filters.at(i).toMap().value("name") == cur.value("name"))
                currentFilter = i;
    }

    QQmlComponent comp(m_engine, "Folio", "FilePicker");
    auto *obj = comp.createWithInitialProperties({
        {"mode", mode},
        {"requestTitle", title},
        {"acceptLabel", options.value("accept_label").toString()},
        {"multiple", options.value("multiple").toBool()},
        {"filters", filters},
        {"currentFilter", currentFilter},
        {"currentName", currentName},
        {"startDir", startDir},
        {"saveNames", mode == "saveFiles" ? QVariant(readByteArrays(options.value("files"))) : QVariant(QStringList{})},
    });
    auto *win = qobject_cast<QQuickWindow *>(obj);
    if (!win) {
        qWarning() << "FilePicker:" << comp.errorString();
        delete obj;
        if (!local)
            QDBusConnection::sessionBus().send(msg.createReply(QVariantList{uint(2), QVariantMap{}}));
        return;
    }
    p.window = win;
    m_pending.insert(id, p);
    win->setProperty("requestId", id);
    // fechar a janela pelo X do compositor = cancelar
    connect(win, &QQuickWindow::visibleChanged, this, [this, id, win] { if (!win->isVisible()) finish(id, 1, {}); });
    connect(win, SIGNAL(finished(bool,QVariant)), this, SLOT(onPickerFinished(bool,QVariant)));
}

void FileChooserPortal::finish(int id, uint response, const QStringList &paths)
{
    if (!m_pending.contains(id))
        return;
    auto p = m_pending.take(id);
    if (!p.handle.isEmpty())
        QDBusConnection::sessionBus().unregisterObject(p.handle);
    if (p.window) {
        p.window->disconnect(this);
        p.window->close();
        p.window->deleteLater();
    }
    if (p.local) {
        for (const auto &path : paths)
            qInfo().noquote() << path;
        return;
    }
    QVariantMap results;
    if (response == 0) {
        QStringList uris;
        for (const auto &path : paths)
            uris << QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded);
        results.insert("uris", uris);
        results.insert("writable", true);
    }
    QDBusConnection::sessionBus().send(p.msg.createReply(QVariantList{response, results}));
}

void FileChooserPortal::cancel(const QString &handle)
{
    for (auto it = m_pending.cbegin(); it != m_pending.cend(); ++it)
        if (it->handle == handle)
            return finish(it.key(), 2, {});
}

void FileChooserPortal::onPickerFinished(bool ok, const QVariant &paths)
{
    const int id = sender()->property("requestId").toInt();
    finish(id, ok ? 0 : 1, paths.toStringList());
}
