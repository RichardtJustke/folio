#pragma once

#include <QAbstractListModel>
#include <QVariantList>

#include "FileEntry.h"

// Achata as entradas em linhas para um ListView virtualizado:
// cada linha é um cabeçalho de seção ou até `columns` itens.
class RowModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles { KindRole = Qt::UserRole + 1, TitleRole, ItemsRole };

    struct Row {
        bool header = false;
        QString title;
        int first = 0; // índice da primeira entrada
        int count = 0;
    };

    explicit RowModel(QObject *parent = nullptr) : QAbstractListModel(parent) {}

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void rebuild(const QList<FileEntry> &entries, int columns, bool grouped);
    int rowOfEntry(int entryIndex) const;
    int verticalNeighbor(int entryIndex, int direction) const; // mesma coluna, linha acima/abaixo
    // entradas cujas células intersectam o retângulo (coordenadas do conteúdo do ListView)
    QList<int> entriesInRegion(qreal x1, qreal y1, qreal x2, qreal y2, qreal headerHeight, qreal rowHeight, qreal cellWidth) const;

    static QString sectionTitle(DateSection s);
    static QVariantMap entryToMap(const FileEntry &e, int index);

private:
    QList<Row> m_rows;
    const QList<FileEntry> *m_entries = nullptr;
};
