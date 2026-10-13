#include <QGuiApplication>
#include <QIcon>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>

#include "Config.h"
#include "FileManager1.h"
#include "IconProvider.h"
#include "Thumbnailer.h"
#include <QDir>

namespace {
// Tema de ícones: config.json > tema da plataforma (qt6ct) > gsettings > Adwaita
void setupIconTheme()
{
    auto theme = Config::load().value("iconTheme").toString();
    if (theme.isEmpty() && !QIcon::themeName().isEmpty() && QIcon::themeName() != "hicolor")
        return;
    if (theme.isEmpty()) {
        QProcess p;
        p.start("gsettings", {"get", "org.gnome.desktop.interface", "icon-theme"});
        if (p.waitForFinished(1000))
            theme = QString::fromUtf8(p.readAllStandardOutput()).trimmed().remove('\'');
    }
    QIcon::setThemeName(theme.isEmpty() ? "Adwaita" : theme);
    QIcon::setFallbackThemeName("hicolor");
}
}

int main(int argc, char *argv[])
{
    QQuickWindow::setDefaultAlphaBuffer(true);
    QGuiApplication app(argc, argv);
    app.setApplicationName("folio");
    app.setOrganizationName("folio");
    app.setDesktopFileName("folio"); // app_id no Wayland -> casa com a window rule
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Folio/assets/folio.svg")));
    QQuickStyle::setStyle("Basic");

    setupIconTheme();
    Thumbnailer::init();

    QQmlApplicationEngine engine;
    // Antes do QML: o Main.qml liga os sinais assim que é criado
    auto *fileManager1 = new FileManager1(&app);
    engine.rootContext()->setContextProperty("fileManager1", fileManager1);
    engine.addImageProvider("icon", new IconProvider);
    engine.addImageProvider("thumb", new ThumbnailProvider);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Folio", "Main");
    fileManager1->registerOnBus();
    return app.exec();
}
