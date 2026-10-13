# Changelog

Cada mudança é uma nova versão (Alpha 0.N), registrada aqui e tagueada no git (`v0.N-alpha`).

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
