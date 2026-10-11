#include "Config.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>

namespace {
QJsonObject defaults()
{
    return QJsonObject{
        {"favorites", QJsonArray{}}, // só os adicionados pelo usuário; as pastas principais são fixas
        {"iconTheme", ""},
        {"showHidden", false},
        {"groupByDate", true},
    };
}
}

namespace Config {

QString path()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/folio/config.json";
}

QJsonObject load()
{
    QFile f(path());
    if (!f.open(QIODevice::ReadOnly)) {
        const auto d = defaults();
        save(d);
        return d;
    }
    auto obj = QJsonDocument::fromJson(f.readAll()).object();
    const auto d = defaults();
    for (auto it = d.begin(); it != d.end(); ++it)
        if (!obj.contains(it.key()))
            obj.insert(it.key(), it.value());
    return obj;
}

void save(const QJsonObject &obj)
{
    QDir().mkpath(QFileInfo(path()).absolutePath());
    QFile f(path());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
}

QString expand(const QString &p)
{
    if (p == "~")
        return QDir::homePath();
    if (p.startsWith("~/"))
        return QDir::homePath() + p.mid(1);
    return p;
}

QString contract(const QString &p)
{
    const auto home = QDir::homePath();
    if (p == home)
        return "~";
    if (p.startsWith(home + "/"))
        return "~" + p.mid(home.size());
    return p;
}

}
