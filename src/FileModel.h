#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QQmlEngine>
#include <QSet>
#include <QTimer>

#include <atomic>
#include <memory>

#include "FileEntry.h"
#include "RowModel.h"

class FileModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QString title READ title NOTIFY pathChanged)
    Q_PROPERTY(bool isTrash READ isTrash NOTIFY pathChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(bool showExtensions READ showExtensions WRITE setShowExtensions NOTIFY showExtensionsChanged)
    Q_PROPERTY(bool groupByDate READ groupByDate WRITE setGroupByDate NOTIFY groupByDateChanged)
    Q_PROPERTY(QString sortKey READ sortKey NOTIFY sortChanged)
    Q_PROPERTY(bool sortDescending READ sortDescending NOTIFY sortChanged)
    Q_PROPERTY(QString viewMode READ viewMode WRITE setViewMode NOTIFY viewModeChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchChanged)
    Q_PROPERTY(bool searchRecursive READ searchRecursive WRITE setSearchRecursive NOTIFY searchChanged)
    Q_PROPERTY(bool isSearch READ isSearch NOTIFY searchChanged)
    Q_PROPERTY(int columns READ columns WRITE setColumns NOTIFY columnsChanged)
    Q_PROPERTY(int count READ count NOTIFY entriesChanged)
    Q_PROPERTY(int revision READ revision NOTIFY entriesChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY entriesChanged)
    Q_PROPERTY(RowModel *rows READ rows CONSTANT)
    Q_PROPERTY(int selectionRevision READ selectionRevision NOTIFY selectionChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(QString renamingPath READ renamingPath WRITE setRenamingPath NOTIFY renamingPathChanged)

public:
    explicit FileModel(QObject *parent = nullptr);
    ~FileModel() override;

    QString path() const { return m_path; }
    void setPath(const QString &path);
    QString title() const;
    bool isTrash() const;
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool v);
    bool showExtensions() const { return m_showExtensions; }
    void setShowExtensions(bool v);
    bool groupByDate() const { return m_groupByDate; }
    void setGroupByDate(bool v);
    QString sortKey() const { return m_sortKey; }
    bool sortDescending() const { return m_sortDesc; }
    QString viewMode() const { return m_viewMode; }
    void setViewMode(const QString &m);
    QString searchQuery() const { return m_query; }
    void setSearchQuery(const QString &q);
    bool searchRecursive() const { return m_recursive; }
    void setSearchRecursive(bool v);
    bool isSearch() const { return !m_query.isEmpty(); }
    int columns() const { return m_columns; }
    void setColumns(int c);
    int count() const { return m_entries.size(); }
    int revision() const { return m_revision; }
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    RowModel *rows() { return &m_rows; }
    int selectionRevision() const { return m_selectionRevision; }
    int selectedCount() const { return m_selected.size(); }
    int currentIndex() const { return m_current; }
    void setCurrentIndex(int i);
    QString renamingPath() const { return m_renamingPath; }
    void setRenamingPath(const QString &p);

    Q_INVOKABLE QVariantMap entry(int index) const;
    Q_INVOKABLE bool isSelected(int index) const;
    Q_INVOKABLE void select(int index, int modifiers = 0);
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE void invertSelection();
    Q_INVOKABLE int selectMatching(const QString &pattern);
    Q_INVOKABLE void selectPath(const QString &path);
    Q_INVOKABLE QStringList selectedPaths() const;
    Q_INVOKABLE int rowOfIndex(int index) const { return m_rows.rowOfEntry(index); }
    Q_INVOKABLE void moveCurrent(int delta, int modifiers = 0);
    Q_INVOKABLE void moveRow(int direction, int modifiers = 0);
    Q_INVOKABLE void sortBy(const QString &key);
    Q_INVOKABLE void beginRubberBand(bool additive);
    Q_INVOKABLE void updateRubberBand(qreal x1, qreal y1, qreal x2, qreal y2,
                                      qreal headerHeight, qreal rowHeight, qreal cellWidth);
    Q_INVOKABLE void reload();
    // posição (0, 1, …) do item que acabou de aparecer na pasta (novo/extraído/colado); -1 se não é novo
    Q_INVOKABLE int freshIndex(const QString &path) const { return m_fresh.value(path, -1); }

signals:
    void pathChanged();
    void showHiddenChanged();
    void showExtensionsChanged();
    void groupByDateChanged();
    void sortChanged();
    void viewModeChanged();
    void searchChanged();
    void columnsChanged();
    void entriesChanged();
    void loadingChanged();
    void selectionChanged();
    void currentIndexChanged();
    void renamingPathChanged();

private:
    void applyEntries(QList<FileEntry> entries, const QString &error, quint64 generation);
    void refilter(); // filtra + ordena m_all em m_entries, preservando seleção/atual
    void rebuildRows();
    void bumpSelection();
    static void persist(const QString &key, const QJsonValue &value);

    QString m_path;
    QString m_error;
    QList<FileEntry> m_all;
    QList<FileEntry> m_entries; // visíveis, na ordem de exibição
    RowModel m_rows;
    QSet<QString> m_selected;
    QSet<QString> m_bandBase;
    QString m_pendingSelect;
    QString m_renamingPath;
    QString m_sortKey = QStringLiteral("name");
    QString m_viewMode = QStringLiteral("grid");
    QString m_query;
    QFileSystemWatcher m_watcher;
    QTimer m_freshTimer;
    QHash<QString, int> m_fresh;
    QSet<QString> m_known;
    QString m_knownDir;
    QTimer m_debounce;
    QTimer m_searchDebounce;
    std::shared_ptr<std::atomic_bool> m_cancel;
    quint64 m_generation = 0;
    int m_columns = 6;
    int m_current = -1;
    int m_anchor = -1;
    int m_selectionRevision = 0;
    int m_revision = 0;
    bool m_showHidden = false;
    bool m_showExtensions = true;
    bool m_groupByDate = true;
    bool m_sortDesc = false;
    bool m_recursive = false;
    bool m_loading = false;
};
