# Changelog

Cada mudança é uma nova versão (Alpha 0.N), registrada aqui e tagueada no git (`v0.N-alpha`).

## Alpha 0.17
- Configurações → Comportamento → "Janela única" (desligada por padrão): abrir o Folio de novo (Super+E, `xdg-open`, outros apps) usa a janela aberta, numa aba nova, em vez de abrir outra janela. Ctrl+N continua abrindo uma janela separada.
- Os pedidos passam pela interface D-Bus `io.github.richardtjustke.Folio` da primeira instância; a nova sai em menos de 0,1 s.

## Alpha 0.16
- Busca rápida (Ctrl+P): uma paleta que procura arquivos e pastas em toda a pasta pessoal enquanto você digita, com os arquivos recentes (`recently-used.xbel`) primeiro e depois os nomes que começam com o termo. Sem texto, lista os recentes.
- ↑/↓ escolhem; Enter abre (pasta: navega até ela); Shift+Enter mostra o item na pasta. Pastas ocultas ficam de fora; a busca roda em segundo plano e para em 40 resultados.

## Alpha 0.15
- Renomear vários itens de uma vez (F2 ou "Renomear…" com mais de um selecionado): **Substituir texto**, **Adicionar texto** (antes ou depois do nome) ou **Numerar** ("Viagem 01", "Viagem 02"…). A extensão é preservada e a prévia mostra antes → depois.
- Tudo é validado antes (nomes repetidos, nomes já existentes) e aceita trocas entre os próprios itens; Ctrl+Z desfaz o lote inteiro.

## Alpha 0.14
- Etiquetas de cor (Vermelho, Laranja, Amarelo, Verde, Azul, Roxo, Cinza): no menu de contexto, uma linha de bolinhas liga/desliga a etiqueta nos itens selecionados (✓ nas que todos já têm).
- As etiquetas aparecem como bolinhas ao lado do tamanho (grade) e no fim do nome (lista).
- Barra lateral → "Etiquetas": clicar numa cor busca os itens com ela em toda a pasta pessoal. Na busca, `tag:Azul` filtra por etiqueta.
- Gravadas no atributo estendido `user.xdg.tags`, o mesmo do Dolphin: valem entre gerenciadores e acompanham o arquivo.

## Alpha 0.13
- Painel de prévia à direita (F3, botão na barra de ferramentas ou menu ⋯): imagem, começo do texto, miniatura ou ícone do item selecionado, com tamanho, datas de modificação e criação, local, destino do link e permissões. Sem seleção mostra a pasta atual; com vários itens, a contagem e o tamanho somado. Some sozinho em janelas com menos de 760 px.
- A Visualização Rápida também usa o estilo de ícones escolhido.
- Modo de teste offscreen para desenvolvimento (`FOLIO_SNAPSHOT` + `FOLIO_KEYS` com `QT_QPA_PLATFORM=offscreen`): envia teclas à própria janela, salva uma captura e sai, sem abrir nada na sessão.

## Alpha 0.12
- F4 abre o terminal na pasta atual (na busca, na pasta do item selecionado). Os menus mostram o atalho ao lado do item.
- Terminal detectado automaticamente quando o campo das Configurações está vazio: `$TERMINAL`, depois o primeiro instalado entre xdg-terminal-exec, kitty, foot, alacritty, wezterm, ghostty, konsole, gnome-terminal, kgx, xfce4-terminal, tilix e xterm. Sem nenhum, um aviso explica onde configurar.

## Alpha 0.11
- Barra de caminho (clique nela ou Ctrl+L): sugestões de pastas enquanto digita; Tab completa (prefixo comum ou a sugestão escolhida), ↑/↓ escolhem, Enter entra, Esc fecha a lista. Abre já com `~/…/` e a barra no fim, pronto para continuar digitando.

## Alpha 0.10
- Lista com cabeçalho discreto: rótulos mais leves ("Modificado" no lugar de "Data de Modificação"), seta de ordenação pequena, e cada rótulo alinhado à sua coluna — "Nome" sobre o nome (depois do ícone), "Tamanho" à direita junto dos valores, "Tipo" sem cortar.
- Linhas sem listras alternadas; seleção em cinza translúcido (como na grade) e realce suave ao passar o mouse.

## Alpha 0.9
- Novos ícones na área de arquivos (grade, lista, Visualização Rápida), desenhados pelo próprio Folio: **Duotone** (padrão — símbolo colorido sobre um quadrado translúcido, uma cor por tipo), **macOS** (pasta azul preenchida, folha branca com etiqueta do tipo: PDF, MP4…), **Contorno**, **Plano** (folha cheia na cor do tipo) e **Sistema** (tema de ícones instalado, sem o pacote embutido). A barra lateral não muda.
- Configurações → Aparência → "Ícones dos arquivos" escolhe o estilo; as pastas seguem a cor de destaque.

## Alpha 0.8
- "Mostrar na pasta" de navegadores e outros apps abre o Folio: implementa `org.freedesktop.FileManager1` no D-Bus (`ShowFolders`, `ShowItems` com o arquivo selecionado, `ShowItemProperties`). Com o Folio aberto vira uma aba nova na janela; fechado, o D-Bus o inicia (`folio --dbus-service`). A instalação fora de `/usr` grava `~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service`, que tem precedência sobre o do Nautilus/Dolphin.
- `folio /caminho/arquivo` abre a pasta com o arquivo selecionado.
- `hypr/folio.lua`: SUPER+E com caminho absoluto (o PATH do Hyprland não inclui `~/.local/bin`, e o atalho não abria nada).

## Alpha 0.7
- Corrige o app que aparecia no launcher/menu de apps mas não abria: ao instalar fora de `/usr` (ex.: `--prefix ~/.local`), o `folio.desktop` agora leva o caminho absoluto do binário, já que `~/.local/bin` não está no PATH de launchers como o quickshell.

## Alpha 0.6
- Pacote de ícones embutido (`assets/icons`, 40+ SVGs no estilo da logo): barra lateral, barra de ferramentas, menus e ícones genéricos de arquivo ficam iguais em qualquer sistema/AppImage, sem depender do tema de ícones instalado. O tema do sistema continua valendo para ícones específicos de tipos de arquivo.

## Alpha 0.5
- Nova logo: pasta azul com aba de vidro fosco e duas folhas saindo (a da frente com canto dobrado) (`assets/folio.svg`), substituindo a folha genérica.

## Alpha 0.4
- Animações em toda a interface, iguais com a barra lateral completa, compacta ou oculta:
  - Excluir: os itens voam até a Lixeira (que pulsa); esvaziar a Lixeira solta partículas; exclusão permanente encolhe no lugar.
  - Itens novos (novo arquivo/pasta, extrair, compactar, colar, renomear) surgem com um "pulo" em cascata; os vizinhos deslizam para o novo lugar.
  - Trocar de pasta desliza o conteúdo 16 px na direção do movimento; abas abrem/fecham com a pílula crescendo/encolhendo; troca de aba e divisão com crossfade.
  - Barra lateral recolhe/expande com animação e os rótulos desvanecem; soltar numa pasta da barra faz o item pulsar.
  - Menus crescem do ponto do clique; diálogos sobem 8 px; Configurações entram com fade; Visualização Rápida cresce a partir da miniatura.
  - Passar o mouse sobe o item 2 px; seleção com transição suave; erro faz o aviso e os itens tremerem; conectar ao servidor mostra um anel girando.
- Configurações → Animações: "Reduzir movimento" (desliga tudo) e velocidade de 0,5× a 2×.

## Alpha 0.3
- Abas sempre visíveis, com botão "+" de nova aba; cada aba tem a sua própria pasta e histórico.
- Divisão da janela: duas abas lado a lado (botão na tira de abas, `Ctrl+\` ou `F6`); divisor arrastável (duplo clique = 50/50); em janela estreita os painéis ficam um sobre o outro.
- Clicar numa aba ou numa pasta da barra lateral fecha as Configurações e vai para ela.
- `docs/animacoes.html`: prévia interativa das animações propostas (ainda não aplicadas no app).

## Alpha 0.2
- Controles da janela sem minimizar (maximizar + fechar); 3 cliques no topo = tela cheia, 2 = maximizar.
- Menus, diálogos e a página de Configurações seguem a transparência da janela.
- Rede: "Conectar ao servidor…" via SSH/SFTP (gvfs), com atalhos dos hosts do `~/.ssh/config`.
- Aplicativos padrão por tipo de arquivo; escolha de fonte e tema de ícones; modo de legibilidade.
- Barra lateral com pastas principais fixas, "Adicionar pasta…" e Configurações.
- Janela em tiling no Hyprland (sem float forçado).

## Alpha 0.1
- Base: grade/lista, abas, busca, lixeira, desfazer, miniaturas, Visualização Rápida.
- Página de Configurações (tema, cor, transparência, ícones, comportamento) e Sobre.
- Ícone do app, barra lateral responsiva, propriedades, abrir com, compactar/extrair, caminho editável.
