#pragma once

#include <QStringList>

// Etiquetas no atributo estendido user.xdg.tags (vírgulas), o mesmo do Dolphin/Baloo:
// acompanham o arquivo ao mover/copiar com preservação de atributos.
namespace Tags {
QStringList read(const QString &path);
bool write(const QString &path, const QStringList &tags);
}
