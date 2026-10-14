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

// image://fileicon/<estilo>/<nomes>?ext=PDF&accent=rrggbb&light=0&glyph=0
// Ícones de arquivo/pasta desenhados aqui (duotone | mac | outline | flat); "system" usa o tema
// do sistema sem o pacote embutido. O tipo vem dos nomes de ícone do mime (application-pdf, video-x-generic...).
class FileIconProvider : public QQuickImageProvider
{
public:
    FileIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
