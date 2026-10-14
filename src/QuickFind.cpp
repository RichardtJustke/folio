#include "QuickFind.h"

#include "Config.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QMimeDatabase>
#include <QUrl>
#include <QXmlStreamReader>
#include <QtConcurrent>

#include <algorithm>

namespace {
constexpr int kMaxResults = 40;
constexpr int kTimeBudgetMs = 2500;

QVariantMap describe(const QFileInfo &fi)
{
    static const QMimeDatabase mimeDb;
    QString icon = QStringLiteral("folder");
    if (!fi.isDir()) {
        const auto mime = mimeDb.mimeTypeForFile(fi, QMimeDatabase::MatchExtension);
        icon = mime.iconName() + "," + mime.genericIconName() + ",text-x-generic";
    }
    return {{"path", fi.absoluteFilePath()}, {"name", fi.fileName()},
            {"location", Config::contract(fi.absolutePath())}, {"isDir", fi.isDir()}, {"icon", icon}};
}

// recentes do freedesktop, mais novos primeiro, só os que ainda existem
QStringList recentFiles()
{
    QFile f(QDir::homePath() + "/.local/share/recently-used.xbel");
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QList<QPair<QDateTime, QString>> items;
    QXmlStreamReader xml(&f);
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (!xml.isStartElement() || xml.name() != QLatin1String("bookmark"))
            continue;
        const QUrl url(xml.attributes().value("href").toString());
        if (url.isLocalFile())
            items.append({QDateTime::fromString(xml.attributes().value("modified").toString(), Qt::ISODate),
                          url.toLocalFile()});
    }
    std::sort(items.begin(), items.end(), [](const auto &a, const auto &b) { return a.first > b.first; });
    QStringList out;
    for (const auto &[when, path] : items) {
        if (!out.contains(path) && QFileInfo::exists(path))
            out.append(path);
        if (out.size() >= 200)
            break;
    }
    return out;
}

QVariantList run(const QString &query, std::shared_ptr<std::atomic_bool> cancel)
{
    QVariantList out;
    QStringList seen;
    const auto add = [&](const QFileInfo &fi) {
        if (seen.contains(fi.absoluteFilePath()))
            return;
        seen.append(fi.absoluteFilePath());
        out.append(describe(fi));
    };

    const auto q = query.trimmed();
    for (const auto &p : recentFiles()) {
        const QFileInfo fi(p);
        if (q.isEmpty() ? out.size() < 12 : fi.fileName().contains(q, Qt::CaseInsensitive))
            add(fi);
    }
    if (q.isEmpty())
        return out;

    // nomes na pasta pessoal (sem entrar em pastas ocultas): primeiro os que começam com o termo
    QVariantList contains;
    QElapsedTimer clock;
    clock.start();
    QDirIterator it(QDir::homePath(), QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext() && !*cancel && clock.elapsed() < kTimeBudgetMs && out.size() < kMaxResults) {
        it.next();
        const auto fi = it.fileInfo();
        if (fi.absoluteFilePath().contains(QLatin1String("/.")))
            continue;
        const auto name = fi.fileName();
        if (name.startsWith(q, Qt::CaseInsensitive))
            add(fi);
        else if (contains.size() < kMaxResults && name.contains(q, Qt::CaseInsensitive))
            contains.append(fi.absoluteFilePath());
    }
    for (const auto &p : std::as_const(contains)) {
        if (out.size() >= kMaxResults)
            break;
        add(QFileInfo(p.toString()));
    }
    return out;
}
}

QuickFind::QuickFind(QObject *parent) : QObject(parent) {}

QuickFind::~QuickFind()
{
    cancel();
}

void QuickFind::cancel()
{
    if (m_cancel)
        *m_cancel = true;
}

void QuickFind::search(const QString &query)
{
    cancel();
    m_cancel = std::make_shared<std::atomic_bool>(false);
    const auto gen = ++m_generation;
    if (!m_searching) {
        m_searching = true;
        emit searchingChanged();
    }
    auto *watcher = new QFutureWatcher<QVariantList>(this);
    connect(watcher, &QFutureWatcher<QVariantList>::finished, this, [this, watcher, gen] {
        watcher->deleteLater();
        if (gen != m_generation)
            return; // já existe uma busca mais nova
        m_results = watcher->result();
        m_searching = false;
        emit resultsChanged();
        emit searchingChanged();
    });
    watcher->setFuture(QtConcurrent::run(run, query, m_cancel));
}
