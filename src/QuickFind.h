#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariantList>

#include <atomic>
#include <memory>

// Busca rápida (Ctrl+P): arquivos recentes (recently-used.xbel) e nomes em toda a pasta pessoal,
// em segundo plano. Vazio = só os recentes.
class QuickFind : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged) // [{path, name, location, isDir, icon}]
    Q_PROPERTY(bool searching READ searching NOTIFY searchingChanged)

public:
    explicit QuickFind(QObject *parent = nullptr);
    ~QuickFind() override;

    QVariantList results() const { return m_results; }
    bool searching() const { return m_searching; }

    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void cancel();
    // recentes do recently-used.xbel, mais novos primeiro: [{path, name, location, isDir, icon, used}]
    Q_INVOKABLE static QVariantList recent(int limit = 12);

signals:
    void resultsChanged();
    void searchingChanged();

private:
    QVariantList m_results;
    bool m_searching = false;
    quint64 m_generation = 0;
    std::shared_ptr<std::atomic_bool> m_cancel;
};
