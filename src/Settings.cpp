#include "Settings.h"

#include "Config.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QKeySequence>
#include <QProcess>
#include <QJsonValue>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
#include <QtGlobal>

#ifndef FOLIO_VERSION
#define FOLIO_VERSION "0.28"
#endif

Settings::Settings(QObject *parent) : QObject(parent)
{
    const auto c = Config::load();
    m_theme = c.value("theme").toString(m_theme);
    m_accent = c.value("accent").toString(m_accent);
    m_opacity = qBound(0.3, c.value("backgroundOpacity").toDouble(m_opacity), 1.0);
    m_radius = qBound(0, c.value("cornerRadius").toInt(m_radius), 28);
    m_iconSize = qBound(40, c.value("iconSize").toInt(m_iconSize), 140);
    m_fontSize = qBound(10, c.value("fontSize").toInt(m_fontSize), 18);
    m_controls = c.value("windowControls").toString(m_controls);
    m_sidebar = c.value("sidebarMode").toString(m_sidebar);
    m_singleClick = c.value("singleClick").toBool(m_singleClick);
    m_confirmTrash = c.value("confirmTrash").toBool(m_confirmTrash);
    m_listPreviews = c.value("showPreviewsInList").toBool(m_listPreviews);
    m_terminal = c.value("terminal").toString();
    m_fontFamily = c.value("fontFamily").toString();
    m_iconTheme = c.value("iconTheme").toString();
    m_fileIcons = c.value("fileIcons").toString(m_fileIcons);
    m_previewPanel = c.value("previewPanel").toBool(m_previewPanel);
    m_singleWindow = c.value("singleWindow").toBool(m_singleWindow);
    m_swipe = c.value("swipeNavigation").toBool(m_swipe);
    m_swipeInvert = c.value("swipeInvert").toBool(m_swipeInvert);
    m_legibility = c.value("legibility").toBool(m_legibility);
    m_reduceMotion = c.value("reduceMotion").toBool(m_reduceMotion);
    m_animSpeed = qBound(0.5, c.value("animationSpeed").toDouble(m_animSpeed), 2.0);
    // restaura geometria e abas
    if (c.contains("windowGeometry")) {
        const auto geom = c.value("windowGeometry").toObject();
        QVariantMap g;
        for (auto it = geom.begin(); it != geom.end(); ++it)
            g.insert(it.key(), it.value().toVariant());
        m_windowGeometry = g;
    }
    if (c.contains("savedTabs")) {
        QVariantList tabs;
        for (const auto &v : c.value("savedTabs").toArray()) {
            QVariantMap t;
            const auto o = v.toObject();
            for (auto it = o.begin(); it != o.end(); ++it)
                t.insert(it.key(), it.value().toVariant());
            tabs.append(t);
        }
        m_savedTabs = tabs;
    }
    m_shortcuts = c.value("shortcuts").toObject().toVariantMap();
    if (!m_fontFamily.isEmpty())
        QGuiApplication::setFont(QFont(m_fontFamily));
}

void Settings::saveShortcuts()
{
    auto cfg = Config::load();
    if (m_shortcuts.isEmpty())
        cfg.remove("shortcuts");
    else
        cfg.insert("shortcuts", QJsonObject::fromVariantMap(m_shortcuts));
    Config::save(cfg);
    emit changed();
}

void Settings::setShortcut(const QString &action, const QStringList &keys)
{
    m_shortcuts.insert(action, keys);
    saveShortcuts();
}

void Settings::resetShortcut(const QString &action)
{
    if (m_shortcuts.remove(action))
        saveShortcuts();
}

QString Settings::keyName(int key, int modifiers) const
{
    switch (key) {
    case Qt::Key_Control: case Qt::Key_Shift: case Qt::Key_Alt: case Qt::Key_Meta:
    case Qt::Key_AltGr: case Qt::Key_Super_L: case Qt::Key_Super_R: case Qt::Key_unknown:
        return {};
    case Qt::Key_Backtab: // Shift+Tab chega como Backtab
        key = Qt::Key_Tab;
        modifiers |= Qt::ShiftModifier;
        break;
    default:
        break;
    }
    const auto mods = Qt::KeyboardModifiers(modifiers) & (Qt::ControlModifier | Qt::AltModifier | Qt::ShiftModifier | Qt::MetaModifier);
    return QKeySequence(QKeyCombination(mods, Qt::Key(key))).toString(QKeySequence::PortableText);
}

void Settings::resetAllShortcuts()
{
    if (m_shortcuts.isEmpty())
        return;
    m_shortcuts.clear();
    saveShortcuts();
}

template<typename T>
void Settings::set(T &field, const T &v, const char *key)
{
    if (field == v)
        return;
    field = v;
    auto cfg = Config::load();
    cfg.insert(QString::fromLatin1(key), QJsonValue(v));
    Config::save(cfg);
    emit changed();
}

void Settings::setTheme(const QString &v) { set(m_theme, v, "theme"); }
void Settings::setAccent(const QString &v) { if (QColor::isValidColorName(v)) set(m_accent, v, "accent"); }
void Settings::setBackgroundOpacity(qreal v) { set(m_opacity, qBound(0.3, v, 1.0), "backgroundOpacity"); }
void Settings::setCornerRadius(int v) { set(m_radius, qBound(0, v, 28), "cornerRadius"); }
void Settings::setIconSize(int v) { set(m_iconSize, qBound(40, v, 140), "iconSize"); }
void Settings::setFontSize(int v) { set(m_fontSize, qBound(10, v, 18), "fontSize"); }
void Settings::setWindowControls(const QString &v) { set(m_controls, v, "windowControls"); }
void Settings::setSidebarMode(const QString &v) { set(m_sidebar, v, "sidebarMode"); }
void Settings::setSingleClick(bool v) { set(m_singleClick, v, "singleClick"); }
void Settings::setConfirmTrash(bool v) { set(m_confirmTrash, v, "confirmTrash"); }
void Settings::setShowPreviewsInList(bool v) { set(m_listPreviews, v, "showPreviewsInList"); }
void Settings::setTerminal(const QString &v) { set(m_terminal, v, "terminal"); }

void Settings::setFontFamily(const QString &v)
{
    set(m_fontFamily, v, "fontFamily");
    if (!v.isEmpty())
        QGuiApplication::setFont(QFont(v));
}

void Settings::setIconTheme(const QString &v)
{
    if (m_iconTheme == v)
        return;
    set(m_iconTheme, v, "iconTheme");
    if (!v.isEmpty())
        QIcon::setThemeName(v);
    ++m_iconRevision; // força as Images a recarregarem (a URL muda)
    emit changed();
}

void Settings::setFileIcons(const QString &v) { set(m_fileIcons, v, "fileIcons"); }
void Settings::setPreviewPanel(bool v) { set(m_previewPanel, v, "previewPanel"); }
void Settings::setSingleWindow(bool v) { set(m_singleWindow, v, "singleWindow"); }
void Settings::setSwipeNavigation(bool v) { set(m_swipe, v, "swipeNavigation"); }
void Settings::setSwipeInvert(bool v) { set(m_swipeInvert, v, "swipeInvert"); }

void Settings::setLegibility(bool v) { set(m_legibility, v, "legibility"); }
void Settings::setReduceMotion(bool v) { set(m_reduceMotion, v, "reduceMotion"); }
void Settings::setAnimationSpeed(qreal v) { set(m_animSpeed, qBound(0.5, v, 2.0), "animationSpeed"); }

void Settings::setWindowGeometry(const QVariantMap &v)
{
    if (m_windowGeometry == v) return;
    m_windowGeometry = v;
    auto cfg = Config::load();
    QJsonObject geom;
    for (auto it = v.begin(); it != v.end(); ++it)
        geom.insert(it.key(), QJsonValue::fromVariant(it.value()));
    cfg.insert("windowGeometry", geom);
    Config::save(cfg);
    emit changed();
}

void Settings::setSavedTabs(const QVariantList &v)
{
    if (m_savedTabs == v) return;
    m_savedTabs = v;
    auto cfg = Config::load();
    QJsonArray arr;
    for (const auto &t : v) {
        QJsonObject o;
        const auto m = t.toMap();
        for (auto it = m.begin(); it != m.end(); ++it)
            o.insert(it.key(), QJsonValue::fromVariant(it.value()));
        arr.append(o);
    }
    cfg.insert("savedTabs", arr);
    Config::save(cfg);
    emit changed();
}

QString Settings::currentIconTheme() const { return QIcon::themeName(); }
QString Settings::detectedTerminal() const { return Config::detectTerminal(); }

QStringList Settings::availableIconThemes() const
{
    QStringList out;
    const QStringList roots = {"/usr/share/icons", "/usr/local/share/icons", QDir::homePath() + "/.local/share/icons",
                               QDir::homePath() + "/.icons"};
    for (const auto &r : roots) {
        for (const auto &name : QDir(r).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            QFile f(r + "/" + name + "/index.theme");
            if (!f.open(QIODevice::ReadOnly))
                continue;
            if (!f.readAll().contains("Directories="))
                continue; // temas só de cursor
            if (name != "hicolor" && name != "default" && !out.contains(name))
                out << name;
        }
    }
    out.sort(Qt::CaseInsensitive);
    return out;
}

QStringList Settings::availableFonts() const { return QFontDatabase::families(); }

void Settings::restart()
{
    QProcess::startDetached(QCoreApplication::applicationFilePath(), {"--new-window"});
    QCoreApplication::quit();
}

void Settings::resetAppearance()
{
    setTheme("dark");
    setAccent("#0a84ff");
    setBackgroundOpacity(0.62);
    setCornerRadius(14);
    setIconSize(76);
    setFontSize(13);
    setWindowControls("right");
    setSidebarMode("auto");
    setLegibility(true);
    setFontFamily("");
    setFileIcons("duotone");
}

QString Settings::home() const { return QDir::homePath(); }
QString Settings::version() const { return QStringLiteral(FOLIO_VERSION); }
QString Settings::qtVersion() const { return QString::fromLatin1(qVersion()); }
QString Settings::configPath() const { return Config::path(); }
