#include "Navigator.h"

#include "Config.h"

#include <QDir>
#include <QFileInfo>

Navigator::Navigator(QObject *parent) : QObject(parent), m_current(QDir::homePath()) {}

void Navigator::reset(const QString &path)
{
    m_back.clear();
    m_forward.clear();
    m_lastLeft.clear();
    m_current = path.startsWith(QLatin1String("folio:")) ? path : QDir::cleanPath(Config::expand(path));
    emit currentPathChanged();
}

void Navigator::go(const QString &path)
{
    const bool virt = path.startsWith(QLatin1String("folio:"));
    const auto p = virt ? path : QDir::cleanPath(Config::expand(path));
    if (p == m_current || (!virt && !QFileInfo(p).isDir()))
        return;
    m_back.append(m_current);
    m_forward.clear();
    setCurrent(p);
}

void Navigator::back()
{
    if (m_back.isEmpty())
        return;
    m_forward.append(m_current);
    setCurrent(m_back.takeLast());
}

void Navigator::forward()
{
    if (m_forward.isEmpty())
        return;
    m_back.append(m_current);
    setCurrent(m_forward.takeLast());
}

void Navigator::up()
{
    if (!canGoUp())
        return;
    go(QFileInfo(m_current).absolutePath());
}

void Navigator::setCurrent(const QString &path)
{
    m_lastLeft = m_current;
    m_current = path;
    emit currentPathChanged();
}
