#include "Thumbnailer.h"

#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QImageReader>
#include <QMimeDatabase>
#include <QMutex>
#include <QProcess>
#include <QRunnable>
#include <QSet>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QThread>
#include <QUrl>

namespace {

constexpr int kSize = 256; // "large"

QSet<QString> g_imageMimes;
QHash<QString, QString> g_thumbnailers; // mime -> Exec
QSet<QString> g_failed;
QMutex g_failedMutex;

QString cacheDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + "/thumbnails/large";
}

QString cacheFile(const QString &uri)
{
    return cacheDir() + "/" + QCryptographicHash::hash(uri.toUtf8(), QCryptographicHash::Md5).toHex() + ".png";
}

void parseThumbnailer(const QString &file)
{
    QFile f(file);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;
    QString exec, tryExec;
    QStringList mimes;
    while (!f.atEnd()) {
        const auto line = QString::fromUtf8(f.readLine()).trimmed();
        if (line.startsWith("Exec="))
            exec = line.mid(5);
        else if (line.startsWith("TryExec="))
            tryExec = line.mid(8);
        else if (line.startsWith("MimeType="))
            mimes = line.mid(9).split(';', Qt::SkipEmptyParts);
    }
    if (exec.isEmpty())
        return;
    const auto bin = tryExec.isEmpty() ? QProcess::splitCommand(exec).value(0) : tryExec;
    if (QStandardPaths::findExecutable(bin).isEmpty() && !QFileInfo(bin).isExecutable())
        return;
    for (const auto &m : mimes)
        if (!g_thumbnailers.contains(m))
            g_thumbnailers.insert(m, exec);
}

bool failed(const QString &key)
{
    QMutexLocker l(&g_failedMutex);
    return g_failed.contains(key);
}

void markFailed(const QString &key)
{
    QMutexLocker l(&g_failedMutex);
    g_failed.insert(key);
}

QImage runThumbnailer(const QString &exec, const QString &path, const QString &uri)
{
    QTemporaryDir tmp;
    if (!tmp.isValid())
        return {};
    const auto out = tmp.filePath("thumb.png");
    QStringList args = QProcess::splitCommand(exec);
    for (auto &a : args) {
        a.replace("%i", path).replace("%u", uri).replace("%o", out).replace("%s", QString::number(kSize));
        a.replace("%%", "%");
    }
    if (args.isEmpty())
        return {};
    QProcess p;
    p.start(args.takeFirst(), args);
    if (!p.waitForFinished(10000)) {
        p.kill();
        p.waitForFinished(500);
        return {};
    }
    return QImage(out);
}

void saveToCache(QImage img, const QString &file, const QString &uri, const QFileInfo &fi, const QString &mime)
{
    QDir().mkpath(cacheDir());
    QFile::setPermissions(cacheDir(), QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
    img.setText("Thumb::URI", uri);
    img.setText("Thumb::MTime", QString::number(fi.lastModified().toSecsSinceEpoch()));
    img.setText("Thumb::Size", QString::number(fi.size()));
    img.setText("Thumb::Mimetype", mime);
    img.setText("Software", "folio");
    const auto tmp = file + QStringLiteral(".folio-%1.tmp").arg(quintptr(QThread::currentThreadId()));
    if (img.save(tmp, "PNG")) {
        QFile::setPermissions(tmp, QFile::ReadOwner | QFile::WriteOwner);
        QFile::remove(file);
        QFile::rename(tmp, file);
    }
}

class ThumbResponse : public QQuickImageResponse, public QRunnable
{
public:
    ThumbResponse(const QString &path, const QSize &size) : m_path(path), m_size(size) { setAutoDelete(false); }

    QQuickTextureFactory *textureFactory() const override { return QQuickTextureFactory::textureFactoryForImage(m_image); }
    QString errorString() const override { return m_image.isNull() ? QStringLiteral("sem miniatura") : QString(); }

    void run() override
    {
        m_image = Thumbnailer::load(m_path);
        if (!m_image.isNull() && m_size.isValid() && (m_image.width() > m_size.width() || m_image.height() > m_size.height()))
            m_image = m_image.scaled(m_size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        emit finished();
    }

private:
    QString m_path;
    QSize m_size;
    QImage m_image;
};

}

namespace Thumbnailer {

void init()
{
    for (const auto &m : QImageReader::supportedMimeTypes())
        g_imageMimes.insert(QString::fromLatin1(m));
    QStringList dirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, "thumbnailers", QStandardPaths::LocateDirectory);
    for (const auto &d : dirs) {
        QDirIterator it(d, {"*.thumbnailer"}, QDir::Files);
        while (it.hasNext())
            parseThumbnailer(it.next());
    }
}

bool isReadableImage(const QString &mime)
{
    return g_imageMimes.contains(mime);
}

bool canThumbnail(const QString &mime)
{
    return g_imageMimes.contains(mime) || g_thumbnailers.contains(mime);
}

QImage load(const QString &path)
{
    const QFileInfo fi(path);
    const auto uri = QString::fromUtf8(QUrl::fromLocalFile(fi.absoluteFilePath()).toEncoded());
    const auto file = cacheFile(uri);
    const auto mtime = QString::number(fi.lastModified().toSecsSinceEpoch());
    const auto key = uri + "@" + mtime;
    if (failed(key))
        return {};

    QImage cached(file);
    if (!cached.isNull() && cached.text("Thumb::MTime") == mtime)
        return cached;

    static const QMimeDatabase db;
    const auto mime = db.mimeTypeForFile(fi).name();
    QImage img;
    if (g_imageMimes.contains(mime)) {
        QImageReader reader(path);
        reader.setAutoTransform(true);
        const auto sz = reader.size();
        if (sz.isValid() && (sz.width() > kSize || sz.height() > kSize))
            reader.setScaledSize(sz.scaled(kSize, kSize, Qt::KeepAspectRatio));
        img = reader.read();
        // imagens pequenas não precisam de cache
        if (!img.isNull() && sz.isValid() && sz.width() <= kSize && sz.height() <= kSize)
            return img;
    } else if (g_thumbnailers.contains(mime)) {
        img = runThumbnailer(g_thumbnailers.value(mime), fi.absoluteFilePath(), uri);
        if (img.width() > kSize || img.height() > kSize)
            img = img.scaled(kSize, kSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    if (img.isNull()) {
        markFailed(key);
        return {};
    }
    if (!fi.absoluteFilePath().startsWith(QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)))
        saveToCache(img, file, uri, fi, mime);
    return img;
}

QString encodeId(const QString &path)
{
    return QString::fromLatin1(path.toUtf8().toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

QString decodeId(const QString &id)
{
    return QString::fromUtf8(QByteArray::fromBase64(id.toLatin1(), QByteArray::Base64UrlEncoding));
}

}

ThumbnailProvider::ThumbnailProvider()
{
    m_pool.setMaxThreadCount(qMax(2, QThread::idealThreadCount() / 2));
}

QQuickImageResponse *ThumbnailProvider::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    const auto path = Thumbnailer::decodeId(id.section('/', 0, 0));
    auto *resp = new ThumbResponse(path, requestedSize);
    m_pool.start(resp);
    return resp;
}
