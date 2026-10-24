#pragma once

#include <QObject>
#include <QQmlEngine>

#include <atomic>
#include <memory>

// Hashes de um arquivo (MD5, SHA-1, SHA-256) numa só leitura, em segundo plano.
class Hasher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString md5 READ md5 NOTIFY resultChanged)
    Q_PROPERTY(QString sha1 READ sha1 NOTIFY resultChanged)
    Q_PROPERTY(QString sha256 READ sha256 NOTIFY resultChanged)
    Q_PROPERTY(QString error READ error NOTIFY resultChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged)

public:
    explicit Hasher(QObject *parent = nullptr);
    ~Hasher() override;

    QString md5() const { return m_md5; }
    QString sha1() const { return m_sha1; }
    QString sha256() const { return m_sha256; }
    QString error() const { return m_error; }
    bool running() const { return m_running; }
    qreal progress() const { return m_progress; }

    Q_INVOKABLE void compute(const QString &path);
    Q_INVOKABLE void clear();
    // qual dos hashes calculados bate com o texto colado ("MD5", "SHA-1", "SHA-256" ou "")
    Q_INVOKABLE QString match(const QString &text) const;

signals:
    void resultChanged();
    void runningChanged();
    void progressChanged();

private:
    void setRunning(bool v);

    QString m_md5, m_sha1, m_sha256, m_error;
    bool m_running = false;
    qreal m_progress = 0;
    quint64 m_generation = 0;
    std::shared_ptr<std::atomic_bool> m_cancel = std::make_shared<std::atomic_bool>(false);
};
