#!/usr/bin/env bash
# Compila e instala o Folio em ~/.local (ou no prefixo passado: ./atualizar.sh /outro/prefixo).
# Também recarrega o D-Bus e, se o seletor de arquivos do Folio estiver ligado, reinicia o portal.
set -euo pipefail

cd "$(dirname "$0")"
PREFIX="${1:-$HOME/.local}"

echo "→ Compilando…"
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build build

echo "→ Instalando em $PREFIX…"
cmake --install build --prefix "$PREFIX" >/dev/null

# serviços D-Bus novos ou alterados (FileManager1, seletor de arquivos) valem sem relogar
busctl --user call org.freedesktop.DBus / org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true

# o seletor (folio --portal) fica rodando em segundo plano: encerra para a próxima janela usar a versão nova
pkill -f "folio --portal" 2>/dev/null || true
if grep -qs "FileChooser=folio" "$HOME/.config/xdg-desktop-portal/"*-portals.conf; then
    systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
fi

VERSION=$(sed -n 's/^set(FOLIO_VERSION_STRING "\(.*\)")/\1/p' CMakeLists.txt)
echo "✓ Folio Alpha $VERSION instalado."
if pgrep -x folio >/dev/null; then
    echo "  O Folio está aberto: feche todas as janelas e abra de novo para usar a versão nova."
fi
