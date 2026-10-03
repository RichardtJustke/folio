#include "RowModel.h"

int RowModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant RowModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    const auto &r = m_rows.at(index.row());
    switch (role) {
    case KindRole:
        return r.header ? QStringLiteral("header") : QStringLiteral("items");
    case TitleRole:
        return r.title;
    case ItemsRole: {
        QVariantList items;
        for (int i = r.first; i < r.first + r.count; ++i)
            items.append(entryToMap(m_entries->at(i), i));
        return items;
    }
    }
    return {};
}

QHash<int, QByteArray> RowModel::roleNames() const
{
    return {{KindRole, "kind"}, {TitleRole, "title"}, {ItemsRole, "items"}};
}

void RowModel::rebuild(const QList<FileEntry> &entries, int columns, bool grouped)
{
    beginResetModel();
    m_entries = &entries;
    m_rows.clear();
    columns = qMax(1, columns);

    int i = 0;
    while (i < entries.size()) {
        int end = i;
        if (grouped) {
            const auto sec = entries.at(i).section;
            while (end < entries.size() && entries.at(end).section == sec)
                ++end;
            m_rows.append({true, sectionTitle(sec), i, 0});
        } else {
            end = entries.size();
        }
        for (int j = i; j < end; j += columns)
            m_rows.append({false, {}, j, qMin(columns, end - j)});
        i = end;
    }
    endResetModel();
}

int RowModel::rowOfEntry(int entryIndex) const
{
    for (int r = 0; r < m_rows.size(); ++r) {
        const auto &row = m_rows.at(r);
        if (!row.header && entryIndex >= row.first && entryIndex < row.first + row.count)
            return r;
    }
    return -1;
}

int RowModel::verticalNeighbor(int entryIndex, int direction) const
{
    const int r = rowOfEntry(entryIndex);
    if (r < 0)
        return -1;
    const int col = entryIndex - m_rows.at(r).first;
    for (int t = r + direction; t >= 0 && t < m_rows.size(); t += direction) {
        const auto &row = m_rows.at(t);
        if (!row.header)
            return row.first + qMin(col, row.count - 1);
    }
    return -1;
}

QList<int> RowModel::entriesInRegion(qreal x1, qreal y1, qreal x2, qreal y2, qreal headerHeight, qreal rowHeight, qreal cellWidth) const
{
    QList<int> out;
    const qreal top = qMin(y1, y2), bottom = qMax(y1, y2);
    const int c1 = qMax(0, int(qMin(x1, x2) / cellWidth));
    const int c2 = int(qMax(x1, x2) / cellWidth);
    qreal y = 0;
    for (const auto &row : m_rows) {
        const qreal h = row.header ? headerHeight : rowHeight;
        if (y > bottom)
            break;
        if (!row.header && y + h >= top)
            for (int c = c1; c <= qMin(c2, row.count - 1); ++c)
                out.append(row.first + c);
        y += h;
    }
    return out;
}

QString RowModel::sectionTitle(DateSection s)
{
    switch (s) {
    case DateSection::Today: return QStringLiteral("Hoje");
    case DateSection::Yesterday: return QStringLiteral("Ontem");
    case DateSection::LastWeek: return QStringLiteral("Últimos 7 dias");
    case DateSection::Older: return QStringLiteral("Mais antigos");
    }
    return {};
}

QVariantMap RowModel::entryToMap(const FileEntry &e, int index)
{
    return {
        {"index", index},
        {"name", e.name},
        {"location", e.location},
        {"typeName", e.typeName},
        {"mime", e.mime},
        {"thumb", e.thumb},
        {"preview", e.preview},
        {"path", e.path},
        {"icon", e.icon},
        {"glyph", e.glyph},
        {"isDir", e.isDir},
        {"isHidden", e.isHidden},
        {"isSymlink", e.isSymlink},
        {"itemCount", e.itemCount},
        {"size", e.size},
        {"modified", e.modified},
    };
}
