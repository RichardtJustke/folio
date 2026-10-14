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
#include <QKeyEvent>
#include <QKeySequence>
#include <QTimer>

namespace {
// Tema de ícones: config.json > tema da plataforma (qt6ct) > gsettings > Adwaita
// Testes sem tocar na sessão do usuário: QT_QPA_PLATFORM=offscreen FOLIO_SNAPSHOT=/tmp/x.png
// FOLIO_KEYS="F3,Right,Ctrl+L,/,u,s" — envia as teclas à janela, salva a captura e sai.
void runSnapshot(QQmlApplicationEngine &engine)
{
    const auto out = qEnvironmentVariable("FOLIO_SNAPSHOT");
    if (out.isEmpty() || engine.rootObjects().isEmpty())
        return;
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win)
        return;
    const auto keys = qEnvironmentVariable("FOLIO_KEYS").split(',', Qt::SkipEmptyParts);
    for (int i = 0; i < keys.size(); ++i) {
        QTimer::singleShot(1500 + i * 250, win, [win, key = keys.at(i)] {
            const auto combo = QKeySequence(key == "comma" ? QStringLiteral(",") : key)[0];
            const auto text = combo.keyboardModifiers() & ~Qt::ShiftModifier ? QString()
                            : key.size() == 1 ? key : QString();
            QKeyEvent press(QEvent::KeyPress, combo.key(), combo.keyboardModifiers(), text);
            QKeyEvent release(QEvent::KeyRelease, combo.key(), combo.keyboardModifiers(), text);
            QGuiApplication::sendEvent(win, &press);
            QGuiApplication::sendEvent(win, &release);
        });
    }
    QTimer::singleShot(2200 + keys.size() * 250, win, [win, out] {
        win->grabWindow().save(out);
        QCoreApplication::quit();
    });
}

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
    engine.addImageProvider("fileicon", new FileIconProvider);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Folio", "Main");
    if (qEnvironmentVariableIsEmpty("FOLIO_SNAPSHOT"))
        fileManager1->registerOnBus();
    runSnapshot(engine);
    return app.exec();
}
