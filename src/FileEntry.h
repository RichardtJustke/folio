#pragma once

#include <QDateTime>
#include <QString>

enum class DateSection { Today, Yesterday, LastWeek, Older };

struct FileEntry {
    QString name;
    QString path;
    QString location;  // pasta pai (abreviada com ~), útil em resultados de busca
    QString icon;      // lista de nomes de ícone separada por vírgula (fallbacks)
    QString glyph;     // ícone simbólico sobreposto à pasta (pastas XDG)
    QString typeName;  // descrição do tipo MIME ("Imagem PNG")
    QString mime;
    QString thumb;     // id para image://thumb/ ("" = sem miniatura)
    QString preview;   // "image" | "text" | "thumb" | "icon"
    QDateTime modified;
    qint64 size = 0;
    int itemCount = -1; // -1 para arquivos ou quando não contado
    bool isDir = false;
    bool isHidden = false;
    bool isSymlink = false;
    DateSection section = DateSection::Older;
};
