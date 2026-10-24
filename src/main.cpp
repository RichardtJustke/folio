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
#include "FileOps.h"
#include "IconProvider.h"
#include "Thumbnailer.h"
#include <QDir>
#include <QKeyEvent>
#include <QKeySequence>
#include <QTimer>
#include <QWheelEvent>

namespace {
// Tema de ícones: config.json > tema da plataforma (qt6ct) > gsettings > Adwaita
// Testes sem tocar na sessão do usuário: QT_QPA_PLATFORM=offscreen FOLIO_SNAPSHOT=/tmp/x.png
// FOLIO_KEYS="F3,Right,Ctrl+L,/,u,s" — envia as teclas à janela, salva a captura e sai.
// "swipe-right"/"swipe-left" simulam dois dedos deslizando no touchpad.
void sendSwipe(QQuickWindow *win, bool right)
{
    const QPointF pos(win->width() / 2.0, win->height() / 2.0);
    const auto send = [&](Qt::ScrollPhase phase, qreal dx) {
        QWheelEvent e(pos, win->mapToGlobal(pos), QPoint(qRound(dx), 0), QPoint(qRound(dx * 4), 0),
                      Qt::NoButton, Qt::NoModifier, phase, false);
        QGuiApplication::sendEvent(win, &e);
    };
    send(Qt::ScrollBegin, 0);
    for (int i = 0; i < 10; ++i)
        send(Qt::ScrollUpdate, right ? -20 : 20); // pixelDelta segue o conteúdo, ao contrário dos dedos
    send(Qt::ScrollEnd, 0);
}

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
            if (key.startsWith("swipe-"))
                return sendSwipe(win, key == "swipe-right");
            const auto combo = QKeySequence(QString(key).replace("comma", ","))[0];
            const auto text = combo.keyboardModifiers() & ~Qt::ShiftModifier ? QString()
                            : key.size() == 1 ? key : key.compare("space", Qt::CaseInsensitive) == 0 ? QStringLiteral(" ") : QString();
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

    // Janela única: se já há um Folio aberto, ele abre a pasta numa aba nova e este processo sai.
    // (--new-window = Ctrl+N; --dbus-service = ativação pelo D-Bus)
    const auto args = QCoreApplication::arguments();
    if (Config::load().value("singleWindow").toBool() && qEnvironmentVariableIsEmpty("FOLIO_SNAPSHOT")
        && !args.contains("--new-window") && !args.contains("--dbus-service")) {
        FileOps probe;
        if (FolioInstance::forward(probe.startPath(), probe.startReveal()))
            return 0;
    }

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
    // em teste (FOLIO_SNAPSHOT) só entra no D-Bus num barramento privado (FOLIO_TEST_BUS)
    if (qEnvironmentVariableIsEmpty("FOLIO_SNAPSHOT") || !qEnvironmentVariableIsEmpty("FOLIO_TEST_BUS")) {
        fileManager1->registerOnBus();
        (new FolioInstance(fileManager1))->registerOnBus();
    }
    runSnapshot(engine);
    return app.exec();
}
