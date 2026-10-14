#pragma once

#include <QColor>
#include <QObject>
#include <QQmlEngine>

// Preferências do usuário (~/.config/folio/config.json). Cada setter persiste na hora.
class Settings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY changed)                       // dark | light
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY changed)                    // #rrggbb
    Q_PROPERTY(qreal backgroundOpacity READ backgroundOpacity WRITE setBackgroundOpacity NOTIFY changed)
    Q_PROPERTY(int cornerRadius READ cornerRadius WRITE setCornerRadius NOTIFY changed)
    Q_PROPERTY(int iconSize READ iconSize WRITE setIconSize NOTIFY changed)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY changed)
    Q_PROPERTY(QString windowControls READ windowControls WRITE setWindowControls NOTIFY changed) // right | left | hidden
    Q_PROPERTY(QString sidebarMode READ sidebarMode WRITE setSidebarMode NOTIFY changed)    // auto | full | compact | hidden
    Q_PROPERTY(bool singleClick READ singleClick WRITE setSingleClick NOTIFY changed)
    Q_PROPERTY(bool confirmTrash READ confirmTrash WRITE setConfirmTrash NOTIFY changed)
    Q_PROPERTY(bool showPreviewsInList READ showPreviewsInList WRITE setShowPreviewsInList NOTIFY changed)
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY changed)
    Q_PROPERTY(QString iconTheme READ iconTheme WRITE setIconTheme NOTIFY changed)
    Q_PROPERTY(int iconRevision READ iconRevision NOTIFY changed)
    Q_PROPERTY(QString fileIcons READ fileIcons WRITE setFileIcons NOTIFY changed)          // duotone | mac | outline | flat | system
    Q_PROPERTY(bool previewPanel READ previewPanel WRITE setPreviewPanel NOTIFY changed)
    Q_PROPERTY(bool legibility READ legibility WRITE setLegibility NOTIFY changed)
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion NOTIFY changed)
    Q_PROPERTY(qreal animationSpeed READ animationSpeed WRITE setAnimationSpeed NOTIFY changed) // 0.5 – 2.0
    Q_PROPERTY(QString terminal READ terminal WRITE setTerminal NOTIFY changed)
    Q_PROPERTY(QString home READ home CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString stage READ stage CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)

public:
    explicit Settings(QObject *parent = nullptr);

    QString theme() const { return m_theme; }
    QString accent() const { return m_accent; }
    qreal backgroundOpacity() const { return m_opacity; }
    int cornerRadius() const { return m_radius; }
    int iconSize() const { return m_iconSize; }
    int fontSize() const { return m_fontSize; }
    QString windowControls() const { return m_controls; }
    QString sidebarMode() const { return m_sidebar; }
    bool singleClick() const { return m_singleClick; }
    bool confirmTrash() const { return m_confirmTrash; }
    bool showPreviewsInList() const { return m_listPreviews; }
    QString terminal() const { return m_terminal; }
    QString fontFamily() const { return m_fontFamily; }
    QString iconTheme() const { return m_iconTheme; }
    int iconRevision() const { return m_iconRevision; }
    QString fileIcons() const { return m_fileIcons; }
    bool previewPanel() const { return m_previewPanel; }
    bool legibility() const { return m_legibility; }
    bool reduceMotion() const { return m_reduceMotion; }
    qreal animationSpeed() const { return m_animSpeed; }
    QString home() const;
    QString version() const;
    QString stage() const { return QStringLiteral("alpha"); }
    QString qtVersion() const;

    void setTheme(const QString &v);
    void setAccent(const QString &v);
    void setBackgroundOpacity(qreal v);
    void setCornerRadius(int v);
    void setIconSize(int v);
    void setFontSize(int v);
    void setWindowControls(const QString &v);
    void setSidebarMode(const QString &v);
    void setSingleClick(bool v);
    void setConfirmTrash(bool v);
    void setShowPreviewsInList(bool v);
    void setTerminal(const QString &v);
    void setFontFamily(const QString &v);
    void setIconTheme(const QString &v);
    void setFileIcons(const QString &v);
    void setPreviewPanel(bool v);
    void setLegibility(bool v);
    void setReduceMotion(bool v);
    void setAnimationSpeed(qreal v);

    Q_INVOKABLE QStringList availableIconThemes() const;
    Q_INVOKABLE QStringList availableFonts() const;
    Q_INVOKABLE QString currentIconTheme() const;
    Q_INVOKABLE QString detectedTerminal() const;
    Q_INVOKABLE void restart();

    Q_INVOKABLE void resetAppearance();
    Q_INVOKABLE QString configPath() const;

signals:
    void changed();

private:
    template<typename T> void set(T &field, const T &v, const char *key);

    QString m_theme = QStringLiteral("dark");
    QString m_accent = QStringLiteral("#0a84ff");
    qreal m_opacity = 0.62;
    int m_radius = 14;
    int m_iconSize = 76;
    int m_fontSize = 13;
    QString m_controls = QStringLiteral("right");
    QString m_sidebar = QStringLiteral("auto");
    bool m_singleClick = false;
    bool m_confirmTrash = true;
    bool m_listPreviews = true;
    QString m_terminal;
    QString m_fontFamily;
    QString m_iconTheme;
    int m_iconRevision = 0;
    QString m_fileIcons = QStringLiteral("duotone");
    bool m_previewPanel = false;
    bool m_legibility = true;
    bool m_reduceMotion = false;
    qreal m_animSpeed = 1.0;
};
