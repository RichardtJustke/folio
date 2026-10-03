#pragma once

#include <QQuickImageProvider>

// image://icon/<nome1,nome2,...>?color=#rrggbb
// Resolve pelo tema de ícones do sistema; `color` tinge ícones simbólicos.
class IconProvider : public QQuickImageProvider
{
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
