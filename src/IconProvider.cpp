#include "IconProvider.h"

#include <QFile>
#include <QHash>
#include <QIcon>
#include <QImage>
#include <QSvgRenderer>
#include <QPainter>
#include <QUrlQuery>

QPixmap IconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int qpos = id.indexOf('?');
    const QString names = qpos < 0 ? id : id.left(qpos);
    const QUrlQuery query(qpos < 0 ? QString() : id.mid(qpos + 1));
    const QSize sz = requestedSize.isValid() ? requestedSize : QSize(64, 64);

    // Ícones embutidos (assets/icons) têm prioridade: iguais em qualquer sistema
    // (menos com ?pack=0, usado pelo estilo "Tema do sistema" da área de arquivos).
    QPixmap pm;
    const bool usePack = query.queryItemValue("pack") != "0";
    for (const auto &n : names.split(',', Qt::SkipEmptyParts)) {
        if (!usePack)
            break;
        const QString path = QStringLiteral(":/qt/qml/Folio/assets/icons/") + n + QStringLiteral(".svg");
        if (!QFile::exists(path))
            continue;
        QSvgRenderer r(path);
        if (!r.isValid())
            continue;
        QImage img(sz, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::transparent);
        QPainter p(&img);
        r.render(&p);
        p.end();
        pm = QPixmap::fromImage(img);
        break;
    }

    QIcon icon;
    for (const auto &n : names.split(',', Qt::SkipEmptyParts)) {
        if (!pm.isNull())
            break;
        if (QIcon::hasThemeIcon(n)) {
            icon = QIcon::fromTheme(n);
            break;
        }
    }
    if (pm.isNull()) {
        if (icon.isNull())
            icon = QIcon::fromTheme("text-x-generic");
        pm = icon.pixmap(sz);
    }
    if (query.hasQueryItem("color") && !pm.isNull()) {
        QPainter p(&pm);
        p.setCompositionMode(QPainter::CompositionMode_SourceIn);
        p.fillRect(pm.rect(), QColor("#" + query.queryItemValue("color")));
    }
    if (size)
        *size = pm.size();
    return pm;
}

namespace {
// Tipo do arquivo a partir dos nomes de ícone do mime (específico primeiro, genérico depois)
QString kindOf(QString names)
{
    // o último nome é sempre o fallback "text-x-generic": não conta para o tipo
    if (names.count(',') >= 2)
        names = names.section(',', 0, -2);
    if (names.startsWith("folder"))
        return "folder";
    const auto has = [&](const char *s) { return names.contains(QLatin1String(s)); };
    if (has("application-pdf"))
        return "pdf";
    if (has("spreadsheet") || has("text-csv"))
        return "sheet";
    if (has("presentation"))
        return "slides";
    if (has("x-office-document") || has("msword") || has("opendocument.text") || has("wordprocessing"))
        return "doc";
    if (has("video-"))
        return "video";
    if (has("image-"))
        return "image";
    if (has("audio-"))
        return "audio";
    if (has("package-x-generic") || has("compressed") || has("-zip") || has("-tar") || has("archive"))
        return "archive";
    if (has("executable") || has("x-sharedlib"))
        return "exec";
    if (has("text-html") || has("text-x-script") || has("text-x-python") || has("text-x-c") || has("javascript")
        || has("json") || has("xml") || has("shellscript") || has("text-x-"))
        return names.startsWith("text-x-generic") ? "text" : "code";
    if (has("text-"))
        return "text";
    return "generic";
}

// Cor por tipo: tons claros para o tema escuro; escurecidos no claro
QColor colorOf(const QString &kind, const QColor &accent, bool light)
{
    static const QHash<QString, QString> c = {
        {"pdf", "#f59088"},   {"text", "#d0d0d6"}, {"code", "#f3b06b"},    {"doc", "#7dbaf5"},
        {"sheet", "#6ad8a4"}, {"slides", "#f3b06b"}, {"video", "#bfa2f7"}, {"image", "#f592b2"},
        {"audio", "#78d8e0"}, {"archive", "#e0c08a"}, {"exec", "#6ad8a4"}, {"generic", "#d0d0d6"},
    };
    QColor col = kind == "folder" ? accent.lighter(135) : QColor(c.value(kind, "#d0d0d6"));
    if (light)
        col = kind == "folder" ? accent : col.darker(kind == "text" || kind == "generic" ? 210 : 150);
    return col;
}

// Versão saturada (fundo de etiqueta / folha cheia)
QColor solidOf(const QString &kind, const QColor &accent)
{
    static const QHash<QString, QString> c = {
        {"pdf", "#d9443c"},   {"text", "#6f7b8a"}, {"code", "#d46a1f"},    {"doc", "#2a7fd4"},
        {"sheet", "#2a8a5c"}, {"slides", "#d46a1f"}, {"video", "#7a4fcf"}, {"image", "#c74b86"},
        {"audio", "#1f8f9a"}, {"archive", "#94703a"}, {"exec", "#2a8a5c"}, {"generic", "#6f7b8a"},
    };
    return kind == "folder" ? accent : QColor(c.value(kind, "#6f7b8a"));
}

// Desenhos em viewBox 24×24. Símbolo solto (duotone) e símbolo dentro da folha (demais estilos).
QString soloGlyph(const QString &kind)
{
    static const QHash<QString, QString> g = {
        {"folder", "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"},
        {"video", "M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zM10 9l5 3-5 3z"},
        {"image", "M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zM3 16l5-5 4 4 3-3 6 6"},
        {"archive", "M4 4h16v16H4zM12 4v2M12 8v2M10 12h4v4h-4z"},
        {"audio", "M9 18a3 3 0 1 1-3-3 3 3 0 0 1 3 3V6l11-2v12M20 16a3 3 0 1 1-3-3 3 3 0 0 1 3 3"},
    };
    return g.value(kind);
}

QString innerGlyph(const QString &kind)
{
    static const QHash<QString, QString> g = {
        {"pdf", "M10 13h6M10 17h6"},  {"text", "M10 13h6M10 17h6"}, {"doc", "M10 13h6M10 17h6"},
        {"code", "M10.5 12.5l-2 2.5 2 2.5M13.5 12.5l2 2.5-2 2.5"},
        {"sheet", "M9.5 12h7v6h-7zM9.5 15h7M13 12v6"},
        {"slides", "M9.5 12h7v5h-7zM13 17v2"},
        {"exec", "M10 13l2 2-2 2M13 17h3"},
        {"video", "M11 12v6l4.5-3z"},
        {"image", "M9 18l3-3.5 2 2 1.5-1.5 1.5 3"},
        {"audio", "M11.5 17.5a1.5 1.5 0 1 1-1.5-1.5 1.5 1.5 0 0 1 1.5 1.5V12l4-1v5"},
        {"archive", "M12 3v1.5M12 6v1.5M10.5 10h3v4h-3z"},
    };
    return g.value(kind);
}

const char *kPage = "M6 1.5h8.5l5 5V21a1.5 1.5 0 0 1-1.5 1.5H6A1.5 1.5 0 0 1 4.5 21V3A1.5 1.5 0 0 1 6 1.5z";
const char *kFold = "M14.5 1.5V5a1.5 1.5 0 0 0 1.5 1.5h3.5z";
const char *kFolderBack = "M2 6a1.5 1.5 0 0 1 1.5-1.5h5.5l2 2h9.5A1.5 1.5 0 0 1 22 8v11a1.5 1.5 0 0 1-1.5 1.5h-17A1.5 1.5 0 0 1 2 19z";
const char *kFolderFront = "M2 9.5A1.5 1.5 0 0 1 3.5 8h17A1.5 1.5 0 0 1 22 9.5V19a1.5 1.5 0 0 1-1.5 1.5h-17A1.5 1.5 0 0 1 2 19z";

QString svgFor(const QString &style, const QString &kind, const QString &ext, const QColor &accent, bool light,
               bool tileOnly, int px)
{
    const auto col = colorOf(kind, accent, light).name();
    const auto solid = solidOf(kind, accent).name();
    QString body;
    if (style == "duotone") {
        auto glyph = soloGlyph(kind);
        if (glyph.isEmpty())
            glyph = QString::fromLatin1("M7 3h7l5 5v13H7zM14 3v5h5") + innerGlyph(kind);
        body = QString("<rect x='1' y='1' width='22' height='22' rx='6.5' fill='%1' fill-opacity='%2'/>")
                   .arg(col).arg(light ? 0.16 : 0.2);
        if (!tileOnly)
            body += QString("<g transform='translate(4.8 4.8) scale(0.6)' fill='none' stroke='%1' stroke-width='%2' "
                            "stroke-linecap='round' stroke-linejoin='round'><path d='%3'/></g>")
                        .arg(col).arg(px < 32 ? 2.2 : 1.7).arg(glyph);
    } else if (style == "mac") {
        if (kind == "folder") {
            body = QString("<path d='%1' fill='%2'/><path d='%3' fill='%4'/>")
                       .arg(kFolderBack, accent.darker(115).name(), kFolderFront, accent.lighter(140).name());
        } else {
            body = QString("<path d='%1' fill='#f2f2f4' stroke='#000' stroke-opacity='.12' stroke-width='.4'/>"
                           "<path d='%2' fill='#c9c9cf'/>").arg(kPage, kFold);
            if (px >= 32 && !ext.isEmpty())
                body += QString("<rect x='6' y='14.5' width='12' height='5' rx='1.2' fill='%1'/>"
                                "<text x='12' y='18.3' text-anchor='middle' font-family='sans-serif' font-weight='bold' "
                                "font-size='%2' fill='#ffffff'>%3</text>")
                            .arg(solid).arg(ext.size() > 3 ? 3.0 : 3.5).arg(ext.toHtmlEscaped());
            else
                body += QString("<rect x='6' y='15' width='12' height='4' rx='1' fill='%1'/>").arg(solid);
        }
    } else if (style == "flat") {
        if (kind == "folder") {
            body = QString("<path d='%1' fill='%2'/><path d='%3' fill='%4'/><path d='M2 9.5A1.5 1.5 0 0 1 3.5 8h17A1.5 1.5 0 0 1 22 9.5v1H2z' fill='#fff' fill-opacity='.2'/>")
                       .arg(kFolderBack, accent.darker(125).name(), kFolderFront, accent.name());
        } else {
            body = QString("<path d='%1' fill='%2'/><path d='%3' fill='#000' fill-opacity='.22'/>"
                           "<path d='%4' fill='none' stroke='#fff' stroke-width='1.4' stroke-linecap='round' stroke-linejoin='round'/>")
                       .arg(kPage, solid, kFold, innerGlyph(kind));
        }
    } else { // outline
        const auto ink = light ? QString("#55555b") : QString("#d6d6d9");
        if (kind == "folder")
            body = QString("<path d='M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM3 10h18' "
                           "fill='none' stroke='%1' stroke-width='1.2' stroke-linejoin='round'/>").arg(col);
        else
            body = QString("<path d='M7 3h7l5 5v13H7zM14 3v5h5%1' fill='none' stroke='%2' stroke-width='1.1' "
                           "stroke-linecap='round' stroke-linejoin='round'/>").arg(innerGlyph(kind), ink);
    }
    return QString("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>%1</svg>").arg(body);
}
}

QPixmap FileIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int qpos = id.indexOf('?');
    const QString path = qpos < 0 ? id : id.left(qpos);
    const QUrlQuery query(qpos < 0 ? QString() : id.mid(qpos + 1));
    const QSize sz = requestedSize.isValid() ? requestedSize : QSize(64, 64);
    const int slash = path.indexOf('/');
    const QString style = path.left(slash);
    const QString names = path.mid(slash + 1);
    const QColor accent("#" + query.queryItemValue("accent"));
    const bool light = query.queryItemValue("light") == "1";

    const auto svg = svgFor(style, kindOf(names), query.queryItemValue("ext").toUpper().left(4),
                            accent.isValid() ? accent : QColor("#0a84ff"), light,
                            query.queryItemValue("tile") == "1", qMin(sz.width(), sz.height()));
    QSvgRenderer r(svg.toUtf8());
    QImage img(sz, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    r.render(&p);
    p.end();
    if (size)
        *size = img.size();
    return QPixmap::fromImage(img);
}
