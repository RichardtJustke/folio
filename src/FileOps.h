#pragma once

#include <QMutex>
#include <QObject>
#include <QQmlEngine>
#include <QStringList>
#include <QWaitCondition>
#include <QElapsedTimer>

#include <atomic>
#include <functional>
#include <memory>

class FileOps : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(qint64 bytesPerSec READ bytesPerSec NOTIFY speedChanged)
    Q_PROPERTY(int etaSeconds READ etaSeconds NOTIFY speedChanged)
    Q_PROPERTY(QString busyLabel READ busyLabel NOTIFY busyChanged)
    Q_PROPERTY(bool canPaste READ canPaste NOTIFY canPasteChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY undoChanged)
    Q_PROPERTY(QString undoLabel READ undoLabel NOTIFY undoChanged)
    Q_PROPERTY(QString trashDir READ trashDir CONSTANT)

public:
    enum ConflictChoice { Skip = 0, KeepBoth = 1, Replace = 2 };
    Q_ENUM(ConflictChoice)

    using Pairs = QList<QPair<QString, QString>>; // (origem, destino)

    struct JobState {
        std::atomic_bool cancel{false};
        QMutex mutex;
        QWaitCondition cond;
        int answer = -1;
        int applyAll = -1;
    };

    struct JobResult {
        QStringList errors;
        Pairs done;
        bool canceled = false;
    };

    explicit FileOps(QObject *parent = nullptr);

    bool busy() const { return m_busy; }
    qreal progress() const { return m_progress; }
    qint64 bytesPerSec() const { return m_bytesPerSec; }
    int etaSeconds() const { return m_etaSeconds; }
    QString busyLabel() const { return m_busyLabel; }
    bool canPaste() const;
    bool canUndo() const { return !m_undo.isEmpty(); }
    QString undoLabel() const;
    QString trashDir() const;

    Q_INVOKABLE QString startPath() const; // argv[1] ou $HOME
    Q_INVOKABLE QString startReveal() const; // argv[1] se for arquivo (abre a pasta com ele selecionado)
    Q_INVOKABLE void open(const QString &path);
    Q_INVOKABLE void openTerminal(const QString &dir);
    Q_INVOKABLE void copy(const QStringList &paths);
    Q_INVOKABLE void cut(const QStringList &paths);
    Q_INVOKABLE void paste(const QString &destDir);
    Q_INVOKABLE void transfer(const QStringList &sources, const QString &destDir, bool move);
    Q_INVOKABLE void dropUrls(const QList<QUrl> &urls, const QString &destDir);
    Q_INVOKABLE void trash(const QStringList &paths);
    Q_INVOKABLE void deletePermanently(const QStringList &paths);
    Q_INVOKABLE void restoreFromTrash(const QStringList &paths);
    Q_INVOKABLE void emptyTrash();
    Q_INVOKABLE QString rename(const QString &path, const QString &newName);
    // renomeia em lote (mesma pasta ou não); valida tudo antes e aceita trocas (a→b, b→a). Devolve quantos.
    Q_INVOKABLE int renameMany(const QStringList &paths, const QStringList &newNames);
    Q_INVOKABLE QString createFolder(const QString &parentDir);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void resolveConflict(int choice, bool applyToAll);

    Q_INVOKABLE QString uriList(const QStringList &paths) const;
    Q_INVOKABLE QUrl fileUrl(const QString &path) const;
    Q_INVOKABLE QString readText(const QString &path, int maxBytes = 65536) const;
    Q_INVOKABLE QString parentDir(const QString &path) const;
    // pastas que completam o caminho digitado (mantém "~/" se o usuário usou); no máximo `limit`
    Q_INVOKABLE QStringList completions(const QString &typed, int limit = 8) const;

    // ── extras estilo Nautilus ──
    Q_INVOKABLE QString createFile(const QString &parentDir);
    // templates de ~/Modelos: cria um novo documento a partir de um deles (ou vazio)
    Q_INVOKABLE QStringList templates() const;
    Q_INVOKABLE QString newFromTemplate(const QString &templatePath, const QString &destDir);
    Q_INVOKABLE void makeLinks(const QStringList &paths);
    // liga a etiqueta em todos (ou desliga, se todos já têm); devolve se ficou ligada
    Q_INVOKABLE bool toggleTag(const QStringList &paths, const QString &tag);
    Q_INVOKABLE QStringList tagsOf(const QString &path) const;
    Q_INVOKABLE void compress(const QStringList &paths, const QString &format); // "zip" | "tar.gz" | "7z"
    Q_INVOKABLE void extract(const QString &archive);
    Q_INVOKABLE bool isArchive(const QString &path) const;
    static bool isArchiveStatic(const QString &path);
    Q_INVOKABLE bool canZip() const;
    Q_INVOKABLE bool can7z() const;
    static QString sevenZipTool();
    Q_INVOKABLE void copyText(const QString &text);
    Q_INVOKABLE void openNewWindow(const QString &path);
    Q_INVOKABLE QVariantList openWithApps(const QString &path) const; // [{name, id, icon}]
    Q_INVOKABLE QVariantList appsForMime(const QString &mime) const;  // [{name, id, icon}]
    Q_INVOKABLE QString defaultAppId(const QString &mime) const;
    Q_INVOKABLE QString defaultAppName(const QString &mime) const;
    Q_INVOKABLE bool setDefaultApp(const QString &mime, const QString &appId);
    Q_INVOKABLE void openWith(const QString &path, const QString &appId);
    Q_INVOKABLE QVariantList sshHosts() const;               // Host do ~/.ssh/config
    Q_INVOKABLE void connectServer(const QString &target);   // [sftp://][user@]host[:porta][/caminho]
    Q_INVOKABLE bool hasNetworkMounts() const;
    Q_INVOKABLE QString networkDir() const; // gvfs montado ou ""
    Q_INVOKABLE QString resolveDir(const QString &typed) const;       // "~/x" -> abs se for pasta, senão ""
    Q_INVOKABLE QVariantMap properties(const QString &path) const;
    Q_INVOKABLE bool setPermissions(const QString &path, int mode);   // mode octal (0755 = 493)
    Q_INVOKABLE void computeSize(const QStringList &paths);

signals:
    void busyChanged();
    void progressChanged();
    void speedChanged();
    void canPasteChanged();
    void undoChanged();
    void errorOccurred(const QString &message);
    void finished(const QString &message);
    void conflict(const QString &name, const QString &destDir, bool isDir);
    void serverConnected(const QString &path);
    void sizeComputed(qint64 bytes, int files, int folders);

private:
    enum class UndoKind { Copy, Move, Rename, Trash, Mkdir };
    struct UndoEntry {
        UndoKind kind;
        Pairs pairs;
    };
    using Job = std::function<JobResult(JobState &, std::function<void(qreal)>)>;

    void setClipboard(const QStringList &paths, bool cut);
    void runJob(const QString &label, const QString &doneMessage, Job job,
                std::function<void(const JobResult &)> onDone = {});
    void pushUndo(UndoKind kind, const Pairs &pairs);
    int askConflict(JobState &state, const QString &name, const QString &destDir, bool isDir);
    void setBusy(bool b, const QString &label = {});
    void setProgress(qreal p);

    std::shared_ptr<JobState> m_job;
    QList<UndoEntry> m_undo;
    QString m_busyLabel;
    qint64 m_bytesPerSec = 0;
    int m_etaSeconds = -1;
    qint64 m_bytesDone = 0;
    qint64 m_bytesTotal = 0;
    QElapsedTimer m_speedTimer;
    qint64 m_lastBytes = 0;
    bool m_busy = false;
    qreal m_progress = 0;
};
