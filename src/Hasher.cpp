#include "Hasher.h"

#include <QCryptographicHash>
#include <QFile>
#include <QFutureWatcher>
#include <QPointer>
#include <QtConcurrent>

namespace {
struct Result {
    QString md5, sha1, sha256, error;
};
}

Hasher::Hasher(QObject *parent) : QObject(parent) {}

Hasher::~Hasher()
{
    *m_cancel = true;
}

void Hasher::setRunning(bool v)
{
    if (v == m_running)
        return;
    m_running = v;
    emit runningChanged();
}

void Hasher::clear()
{
    *m_cancel = true;
    m_cancel = std::make_shared<std::atomic_bool>(false);
    ++m_generation;
    m_md5.clear();
    m_sha1.clear();
    m_sha256.clear();
    m_error.clear();
    m_progress = 0;
    emit resultChanged();
    emit progressChanged();
    setRunning(false);
}

void Hasher::compute(const QString &path)
{
    clear();
    setRunning(true);
    const auto gen = m_generation;
    const auto cancel = m_cancel;
    QPointer<Hasher> self(this);
    auto *watcher = new QFutureWatcher<Result>(this);
    connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher, gen] {
        const auto r = watcher->result();
        watcher->deleteLater();
        if (gen != m_generation)
            return;
        m_md5 = r.md5;
        m_sha1 = r.sha1;
        m_sha256 = r.sha256;
        m_error = r.error;
        m_progress = 1;
        emit resultChanged();
        emit progressChanged();
        setRunning(false);
    });
    watcher->setFuture(QtConcurrent::run([path, cancel, self, gen]() -> Result {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly))
            return {{}, {}, {}, QStringLiteral("Não foi possível ler o arquivo")};
        QCryptographicHash md5(QCryptographicHash::Md5), sha1(QCryptographicHash::Sha1),
            sha256(QCryptographicHash::Sha256);
        const qint64 total = qMax<qint64>(1, f.size());
        qint64 done = 0;
        int lastPct = -1;
        QByteArray buf(1 << 20, Qt::Uninitialized);
        while (!f.atEnd()) {
            if (*cancel)
                return {};
            const auto n = f.read(buf.data(), buf.size());
            if (n < 0)
                return {{}, {}, {}, QStringLiteral("Erro ao ler o arquivo")};
            const QByteArrayView chunk(buf.constData(), n);
            md5.addData(chunk);
            sha1.addData(chunk);
            sha256.addData(chunk);
            done += n;
            const int pct = int(done * 100 / total);
            if (pct != lastPct) {
                lastPct = pct;
                QMetaObject::invokeMethod(qApp, [self, gen, pct] {
                    if (!self || gen != self->m_generation)
                        return;
                    self->m_progress = pct / 100.0;
                    emit self->progressChanged();
                });
            }
        }
        return {QString::fromLatin1(md5.result().toHex()), QString::fromLatin1(sha1.result().toHex()),
                QString::fromLatin1(sha256.result().toHex()), {}};
    }));
}

QString Hasher::match(const QString &text) const
{
    const auto t = text.trimmed().toLower();
    if (t.isEmpty())
        return {};
    if (t == m_md5)
        return QStringLiteral("MD5");
    if (t == m_sha1)
        return QStringLiteral("SHA-1");
    if (t == m_sha256)
        return QStringLiteral("SHA-256");
    return {};
}
