#include "IconProvider.h"

#include <QFile>
#include <QIcon>
#include <QImage>
#include <QSvgRenderer>
#include <QPainter>
#include <QUrlQuery>

QPixmap IconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int qpos = id.indexOf('?');
    const QString names = qpos < 0 ? id : id.left(qpos);
    const QUrlQuery query(qpos < 0 ? QString() : id.mid(qpos + 1));
    const QSize sz = requestedSize.isValid() ? requestedSize : QSize(64, 64);

    // Ícones embutidos (assets/icons) têm prioridade: iguais em qualquer sistema.
    QPixmap pm;
    for (const auto &n : names.split(',', Qt::SkipEmptyParts)) {
        const QString path = QStringLiteral(":/qt/qml/Folio/assets/icons/") + n + QStringLiteral(".svg");
        if (!QFile::exists(path))
            continue;
        QSvgRenderer r(path);
        if (!r.isValid())
            continue;
        QImage img(sz, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::transparent);
        QPainter p(&img);
        r.render(&p);
        p.end();
        pm = QPixmap::fromImage(img);
        break;
    }

    QIcon icon;
    for (const auto &n : names.split(',', Qt::SkipEmptyParts)) {
        if (!pm.isNull())
            break;
        if (QIcon::hasThemeIcon(n)) {
            icon = QIcon::fromTheme(n);
            break;
        }
    }
    if (pm.isNull()) {
        if (icon.isNull())
            icon = QIcon::fromTheme("text-x-generic");
        pm = icon.pixmap(sz);
    }
    if (query.hasQueryItem("color") && !pm.isNull()) {
        QPainter p(&pm);
        p.setCompositionMode(QPainter::CompositionMode_SourceIn);
        p.fillRect(pm.rect(), QColor("#" + query.queryItemValue("color")));
    }
    if (size)
        *size = pm.size();
    return pm;
}
