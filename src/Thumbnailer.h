#pragma once

#include <QImage>
#include <QQuickAsyncImageProvider>
#include <QThreadPool>
#include <QString>

// Miniaturas pela especificação freedesktop (~/.cache/thumbnails/large).
// Imagens são geradas internamente; outros tipos usam os .thumbnailer do sistema
// (/usr/share/thumbnailers: ffmpegthumbnailer, evince, gnome-desktop...).
namespace Thumbnailer {
void init(); // chamar no main antes de qualquer thread usar
bool canThumbnail(const QString &mime);
bool isReadableImage(const QString &mime);
QImage load(const QString &path); // cache ou gera (bloqueante)
QString encodeId(const QString &path);
QString decodeId(const QString &id);
}

// image://thumb/<id base64url>/<mtime>
class ThumbnailProvider : public QQuickAsyncImageProvider
{
public:
    ThumbnailProvider();
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

private:
    QThreadPool m_pool;
};
