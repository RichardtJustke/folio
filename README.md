# Folio

Gerenciador de arquivos estilo Finder para Linux/Wayland — Qt 6 + QML, backend C++.

## Recursos

- Grade agrupada por data (Hoje, Ontem, Últimos 7 dias, Mais antigos) ou lista com colunas ordenáveis
- Abas, histórico voltar/avançar, favoritos configuráveis, drives montados com ejetar
- Miniaturas freedesktop (`~/.cache/thumbnails`, usa os `.thumbnailer` do sistema) e Visualização Rápida (Espaço)
- Busca na pasta atual ou em subpastas
- Arrastar e soltar (inclusive entre apps), seleção por retângulo
- Copiar/mover com progresso, cancelar e diálogo de conflito; desfazer (Ctrl+Z)
- Lixeira freedesktop: mover, restaurar, excluir permanentemente, esvaziar

## Estrutura

```
folio/
├── CMakeLists.txt  PKGBUILD
├── assets/folder.svg
├── dist/folio.desktop
├── hypr/folio.lua
├── src/
│   ├── main.cpp            # janela, tema de ícones, image providers
│   ├── IconProvider.*      # image://icon/<nomes>?color=<hex>
│   ├── Thumbnailer.*       # image://thumb/<id> — cache e geração de miniaturas
│   ├── FileModel.*         # listagem/busca assíncronas, ordenação, filtro, seleção, watcher
│   ├── RowModel.*          # linhas (cabeçalho | N itens) para ListView virtualizado
│   ├── Navigator.*         # histórico
│   ├── FileOps.*           # transferências, conflitos, desfazer, lixeira, clipboard, DnD
│   ├── PlacesModel.*       # favoritos + volumes (/proc/self/mounts)
│   └── Config.*            # ~/.config/folio/config.json
└── qml/
    ├── Main.qml  Theme.qml
    └── components/
        ├── BrowserTab  TabStrip  HeaderBar  NavPill  SearchField  TrafficLights
        ├── Sidebar  SidebarItem
        ├── FileGrid  FileTile  FileListRow  ListHeader  FileInteraction  RenameField
        ├── FolderIcon  SectionHeader  QuickLook
        └── GlassMenu  GlassMenuItem  GlassPopup  DialogButton  ConfirmDialog  ConflictDialog
            ResizeHandles  Toast
```

## Dependências (Arch)

```sh
sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative qt6-svg xdg-utils udisks2
# opcional: tema de ícones com mais tipos de arquivo
sudo pacman -S papirus-icon-theme ffmpegthumbnailer   # mais ícones, miniaturas de vídeo
```

## Build e instalação

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/folio ~/Downloads             # testar

cmake --install build --prefix ~/.local   # binário em ~/.local/bin, .desktop em ~/.local/share/applications
xdg-mime default folio.desktop inode/directory   # opcional: gerenciador padrão
# ~/.local também instala o serviço D-Bus FileManager1: "Mostrar na pasta" dos outros apps abre o Folio
busctl --user call org.freedesktop.DBus / org.freedesktop.DBus ReloadConfig   # aplica sem relogar
```

Ou como pacote: `makepkg -si` na raiz do projeto.

## Hyprland

```sh
cp hypr/folio.lua ~/.config/hypr/config/folio.lua
echo 'require("config/folio")' >> ~/.config/hypr/hyprland.lua
hyprctl reload
```

## Configuração — `~/.config/folio/config.json`

```json
{
  "favorites": [
    { "name": "Downloads", "path": "~/Downloads", "icon": "folder-download-symbolic" }
  ],
  "iconTheme": "",        // vazio = qt6ct/gsettings/Adwaita
  "showHidden": false,
  "groupByDate": true,
  "viewMode": "grid",     // "grid" | "list"
  "sortKey": "name",      // "name" | "modified" | "size" | "type"
  "sortDescending": false
}
```

Favoritos também via menu de contexto (“Adicionar aos Favoritos” / “Remover dos Favoritos”).

## Atalhos

| Tecla | Ação |
|---|---|
| Duplo clique / Enter | Abrir |
| Espaço | Visualização Rápida |
| Alt+← / Backspace, Alt+→, Alt+↑, Alt+Home | Voltar, avançar, subir, pasta pessoal |
| Ctrl+C / Ctrl+X / Ctrl+V | Copiar / recortar / colar |
| Ctrl+Z | Desfazer |
| Delete / Shift+Delete | Lixeira / excluir permanentemente |
| F2 | Renomear |
| Ctrl+Shift+N | Nova pasta |
| Ctrl+F / Ctrl+L | Buscar |
| Ctrl+1 / Ctrl+2 | Ícones / lista |
| Ctrl+H | Mostrar/ocultar ocultos |
| Ctrl+T / Ctrl+W / Ctrl+Tab | Nova aba / fechar aba / próxima aba |
| Ctrl+\ / F6 | Dividir a janela (duas abas lado a lado) |
| Clique do meio numa pasta | Abrir em nova aba |
| Ctrl+A, setas, Shift+setas, Ctrl/Shift+clique, arrastar no vazio | Seleção |
| Arrastar com Ctrl / Shift | Forçar cópia / forçar mover |
| F5 / Ctrl+R | Recarregar |
| Ctrl+Q | Fechar |
