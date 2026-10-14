#pragma once

#include <QJsonObject>
#include <QString>

// ~/.config/folio/config.json
namespace Config {
QString path();
QJsonObject load();
void save(const QJsonObject &obj);
QString expand(const QString &path); // "~/x" -> "/home/u/x"
QString contract(const QString &path);
// terminal para "Abrir Terminal Aqui": config > $TERMINAL > primeiro emulador conhecido instalado
QString terminal();
QString detectTerminal(); // ignora o config (mostra o padrão nas Configurações)
}
