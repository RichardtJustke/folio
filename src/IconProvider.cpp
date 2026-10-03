#include "IconProvider.h"

#include <QIcon>
#include <QPainter>
#include <QUrlQuery>

QPixmap IconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int qpos = id.indexOf('?');
    const QString names = qpos < 0 ? id : id.left(qpos);
    const QUrlQuery query(qpos < 0 ? QString() : id.mid(qpos + 1));
    const QSize sz = requestedSize.isValid() ? requestedSize : QSize(64, 64);

    QIcon icon;
    for (const auto &n : names.split(',', Qt::SkipEmptyParts)) {
        if (QIcon::hasThemeIcon(n)) {
            icon = QIcon::fromTheme(n);
            break;
        }
    }
    if (icon.isNull())
        icon = QIcon::fromTheme("text-x-generic");

    QPixmap pm = icon.pixmap(sz);
    if (query.hasQueryItem("color") && !pm.isNull()) {
        QPainter p(&pm);
        p.setCompositionMode(QPainter::CompositionMode_SourceIn);
        p.fillRect(pm.rect(), QColor("#" + query.queryItemValue("color")));
    }
    if (size)
        *size = pm.size();
    return pm;
}
