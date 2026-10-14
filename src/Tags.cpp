#include "Tags.h"

#include <QFile>
#include <sys/xattr.h>

namespace {
constexpr const char *kAttr = "user.xdg.tags";
}

QStringList Tags::read(const QString &path)
{
    const auto p = QFile::encodeName(path);
    char buf[1024];
    const auto n = getxattr(p.constData(), kAttr, buf, sizeof(buf));
    if (n <= 0)
        return {};
    QStringList out;
    for (const auto &t : QString::fromUtf8(buf, n).split(',', Qt::SkipEmptyParts))
        out.append(t.trimmed());
    return out;
}

bool Tags::write(const QString &path, const QStringList &tags)
{
    const auto p = QFile::encodeName(path);
    if (tags.isEmpty())
        return removexattr(p.constData(), kAttr) == 0 || errno == ENODATA;
    const auto v = tags.join(',').toUtf8();
    return setxattr(p.constData(), kAttr, v.constData(), v.size(), 0) == 0;
}
