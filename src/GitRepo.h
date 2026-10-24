#pragma once

#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QSet>
#include <QStringList>

class QProcess;

// Repositório Git da pasta aberta: branch, à frente/atrás, estado de cada arquivo e ações
// (trocar/criar branch, pull, push, fetch). Tudo por "git" em segundo plano, sem pedir senha.
class GitRepo : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)    // pasta aberta
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY pathChanged)
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)                // a pasta está num repositório
    Q_PROPERTY(QString root READ root NOTIFY stateChanged)
    Q_PROPERTY(QString branch READ branch NOTIFY stateChanged)
    Q_PROPERTY(QString upstream READ upstream NOTIFY stateChanged)
    Q_PROPERTY(int ahead READ ahead NOTIFY stateChanged)
    Q_PROPERTY(int behind READ behind NOTIFY stateChanged)
    Q_PROPERTY(int changes READ changes NOTIFY stateChanged)               // arquivos modificados/novos
    Q_PROPERTY(QStringList branches READ branches NOTIFY stateChanged)
    Q_PROPERTY(int revision READ revision NOTIFY stateChanged)            // muda a cada leitura (bindings dos ícones)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString busyLabel READ busyLabel NOTIFY busyChanged)

public:
    explicit GitRepo(QObject *parent = nullptr);

    QString path() const { return m_path; }
    void setPath(const QString &path);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool v);
    bool active() const { return !m_root.isEmpty(); }
    QString root() const { return m_root; }
    QString branch() const { return m_branch; }
    QString upstream() const { return m_upstream; }
    int ahead() const { return m_ahead; }
    int behind() const { return m_behind; }
    int changes() const { return m_changes; }
    QStringList branches() const { return m_branches; }
    int revision() const { return m_revision; }
    bool busy() const { return m_busy; }
    QString busyLabel() const { return m_busyLabel; }

    // "M" modificado, "A" adicionado, "?" novo (fora do Git), "D" removido, "R" renomeado,
    // "U" em conflito, "dir" pasta com mudanças dentro, "" sem mudança
    Q_INVOKABLE QString statusOf(const QString &absPath) const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void switchBranch(const QString &name);
    Q_INVOKABLE void createBranch(const QString &name);
    Q_INVOKABLE void pull();
    Q_INVOKABLE void push();
    Q_INVOKABLE void fetch();

signals:
    void pathChanged();
    void stateChanged();
    void busyChanged();
    void message(const QString &text, bool error);

private:
    void clear();
    void readStatus();
    void run(const QStringList &args, const QString &label, const QString &done);

    QString m_path, m_root, m_branch, m_upstream, m_busyLabel;
    bool m_enabled = true;
    bool m_busy = false;
    int m_ahead = 0, m_behind = 0, m_changes = 0, m_revision = 0;
    QStringList m_branches;
    QHash<QString, QString> m_status; // caminho absoluto → código
    QSet<QString> m_dirtyDirs;
    quint64 m_generation = 0;
};
