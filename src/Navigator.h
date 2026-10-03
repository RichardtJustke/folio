#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QStringList>

class Navigator : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentPathChanged)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY currentPathChanged)
    Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY currentPathChanged)
    Q_PROPERTY(bool canGoUp READ canGoUp NOTIFY currentPathChanged)
    Q_PROPERTY(QString lastLeft READ lastLeft NOTIFY currentPathChanged)

public:
    explicit Navigator(QObject *parent = nullptr);

    QString currentPath() const { return m_current; }
    bool canGoBack() const { return !m_back.isEmpty(); }
    bool canGoForward() const { return !m_forward.isEmpty(); }
    bool canGoUp() const { return m_current != "/"; }
    // pasta de onde viemos (para re-selecioná-la ao voltar/subir)
    QString lastLeft() const { return m_lastLeft; }

    Q_INVOKABLE void reset(const QString &path); // sem histórico (nova aba)
    Q_INVOKABLE void go(const QString &path);
    Q_INVOKABLE void back();
    Q_INVOKABLE void forward();
    Q_INVOKABLE void up();

signals:
    void currentPathChanged();

private:
    void setCurrent(const QString &path);

    QString m_current;
    QString m_lastLeft;
    QStringList m_back;
    QStringList m_forward;
};
