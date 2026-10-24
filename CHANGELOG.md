# Changelog

Cada mudança é uma nova versão (Alpha 0.N), registrada aqui e tagueada no git (`v0.N-alpha`).

## Alpha 0.30
- Integração com Git: em pastas de um repositório aparece no topo a branch atual, ↑/↓ (commits à frente/atrás do remoto) e quantos arquivos mudaram. O clique abre o menu: trocar de branch, **Nova Branch…**, **Atualizar (Pull)**, **Enviar (Push)** (na primeira vez já cria o upstream), **Buscar (Fetch)**, abrir terminal ou ir para a raiz do repositório.
- Arquivos marcados na grade e na lista: M modificado (laranja), A adicionado (verde), + novo fora do Git (azul), D removido, R renomeado e U em conflito (vermelho); pastas com mudanças dentro levam uma bolinha.
- O git nunca pede senha (sem prompt no terminal, SSH em modo não interativo): se precisar de credenciais, aparece o erro do git num aviso.
- Ações do Git também na paleta de comandos e em Configurações → Atalhos. Configurações → Comportamento → "Integração com Git" desliga tudo.
- Paleta de comandos: o comando roda depois que ela fecha, então diálogos abertos por ele (ex.: Nova branch) já recebem o foco.

## Alpha 0.29
- Barra de ferramentas personalizável (Configurações → Janela e barra lateral, ou clique direito no topo → "Personalizar Barra de Ferramentas…"): cada botão vira um cartão com ‹ › para reordenar e × para tirar; "+ Adicionar" traz os que estão de fora. Botões novos disponíveis: Dividir janela, Nova aba, Pasta acima, Recarregar, Início, Terminal, Paleta de comandos, Busca rápida e Copiar caminho. "Restaurar" volta ao padrão.
- Os botões do topo mostram uma dica com o nome e o atalho ao passar o mouse.
- Paleta de comandos: comandos com todas as palavras digitadas no nome vêm antes dos que só batem pelo grupo.
- Modo de teste: `space` em `FOLIO_KEYS` digita um espaço.

## Alpha 0.28
- Reatribuir teclas (Configurações → Gestos e atalhos): todas as ações listadas por grupo com o atalho atual. Clique no atalho e aperte a combinação nova; Backspace deixa sem atalho, Esc cancela. Se a combinação já era de outra ação, ela sai de lá (e aparece o aviso "Tirado de “…”"). ↺ volta ao padrão de uma ação; "Restaurar todos" volta todos.
- Os atalhos trocados valem também na paleta de comandos e nas dicas dos menus. Ficam em `shortcuts` no `config.json`.
- Correção: ícones de pasta pedidos com tamanho zero geravam avisos (e imagens vazias) ao montar a imagem do arraste.

## Alpha 0.27
- Paleta de comandos (Ctrl+Shift+P): procura qualquer ação pelo nome (sem precisar de acentos) e mostra o atalho ao lado. Também traz configurações: abrir cada aba das Configurações, trocar o tema, o modo da barra lateral, o estilo dos ícones, ligar/desligar animações, gestos e abrir com um clique. Os comandos usados por último aparecem primeiro; os que não valem no momento (ex.: Colar na Lixeira) ficam esmaecidos.
- Novos comandos sem atalho: "Ir para o Início", "Ir para Recentes", "Ir para a Lixeira".
- Por dentro: todos os atalhos de teclado vêm de uma lista única de ações (base para reatribuir teclas).

## Alpha 0.26
- Hashes nas Propriedades (Alt+Enter) de um arquivo: MD5, SHA-1 e SHA-256, calculados numa só leitura em segundo plano (arquivos de até 200 MB na hora; maiores pelo botão "Calcular", com progresso). Cada um tem botão de copiar.
- "Cole um hash para comparar": diz se confere e com qual dos três.

## Alpha 0.25
- Barra lateral **Some sozinha** (Configurações → Janela e barra lateral): fica oculta e os arquivos usam a janela toda. Encostar o cursor na borda esquerda faz ela aparecer flutuando por cima, com sombra; ela some quando o cursor se afasta, ao escolher um lugar ou com Esc. Arrastar um arquivo até a borda também abre a barra, para soltar numa pasta. Ctrl+B mostra/esconde.
- O modo "Auto" passa a se chamar "Pela largura".

## Alpha 0.24
- Arrastar vários itens mostra os ícones empilhados (até 3, cada um com o seu tipo) e a quantidade discreta no canto do ícone da frente. Com um item só, aparece só o ícone, como na grade.

## Alpha 0.23
- Configurações em abas: Aparência, Janela e barra lateral, Animações, Comportamento, Gestos e atalhos, Aplicativos padrão e Sobre, numa lista à esquerda (só ícones em janela estreita).
- Busca no topo: ao abrir as Configurações já dá para digitar; mostra as opções de todas as abas que batem, agrupadas, e a contagem ao lado de cada aba. Esc limpa a busca (com ela vazia, fecha).
- Tema em cartões com prévia e a opção nova **Automático**, que segue o modo claro/escuro do sistema.
- Modo de teste: `Ctrl+comma` em `FOLIO_KEYS`.

## Alpha 0.22
- Página **Início** (primeiro item da barra lateral): Acesso rápido com as pastas fixadas e as pastas que você usou por último (o alfinete fixa ou desafixa), Discos com barra de uso e espaço livre, e Arquivos recentes com a pasta e quando foram abertos. Cada seção recolhe pela setinha; clique direito abre "Mostrar na Pasta", "Copiar Caminho"…
- Soltar arquivos num bloco do Acesso rápido copia para aquela pasta.
- A pasta pessoal aparece em "Locais" como "Pasta pessoal".
- `folio folio:home` abre direto no Início.
- Correção: "Recentes" na barra lateral não abria.
- `docs/mockups-inicio-config.html`: as propostas de Início, Configurações em abas, contador ao arrastar e barra lateral automática.

## Alpha 0.21
- Gestos do touchpad: deslizar dois dedos para a direita volta, para a esquerda avança, como nos navegadores. Uma bolinha com a seta entra pela borda enquanto os dedos deslizam e fica na cor de destaque quando soltar já vai navegar. A rolagem vertical continua igual, e a vista em colunas segue rolando para o lado.
- Configurações → Comportamento: "Gestos do touchpad" (ligado por padrão) e "Inverter direção do gesto".
- Modo de teste: `swipe-right`/`swipe-left` em `FOLIO_KEYS` simulam o gesto.

## Alpha 0.20
- Correção: o menu de contexto dos itens não enxergava a seleção no Qt 6.12. As ações (Copiar, Renomear, Propriedades, Mover para a Lixeira…) agiam sobre nada, e as opções de pasta (Abrir em Nova Aba, Colar na Pasta, Abrir Terminal Aqui, Adicionar aos Favoritos) sumiam. O mesmo valia para o "Padrão" de cada tipo nas Configurações.
- Shift+F10 (ou a tecla Menu) abre o menu de contexto dos itens selecionados.

## Alpha 0.19
- Painel de prévia (F3) redesenhado: prévia maior com cantos arredondados, nome e tipo, e uma fileira de ações rápidas (Abrir, Visualização Rápida, Copiar caminho, Propriedades).
- Os detalhes ficam em cartões com ícones: Tamanho, Onde, Aponta para e Abre com; Criado, Modificado e Acessado; Acesso (permissões por extenso, ex.: "Só justke: leitura e escrita") e Etiquetas.
- Correção: abrir um arquivo compactado com duplo clique entra nele corretamente.

## Alpha 0.18
- Vista em colunas (Ctrl+3 ou menu → "Colunas"): cada subpasta escolhida abre a coluna seguinte, com uma barra de caminho para voltar.
- Lembra as abas e o tamanho/posição da janela: abrir o Folio sem caminho reabre as abas da última sessão (abrir uma pasta específica continua abrindo só ela).
- Abas: arrastar para reordenar e menu de contexto (Nova Aba, Fechar, Fechar Outras, Fechar à Direita).
- Arquivos compactados (.zip, .tar.gz, .tar, .7z): "Entrar no arquivo" lista o conteúdo como uma pasta; dentro dele, "Extrair Aqui".
- Barra lateral: Recentes, pastas inteligentes (buscas salvas por nome ou `tag:`) e espaço livre dos volumes.
- "Novo Documento…" a partir dos modelos de `~/Modelos`; "Enviar por E-mail" no menu de contexto.
- Ctrl+E mostra/oculta as extensões dos arquivos.
- Renomear vários: modos **Regex** (com `$1`, `$2`…) e **Caixa** (minúsculas, MAIÚSCULAS, Title Case).
- Visualização Rápida toca vídeo e áudio (Qt Multimedia).
- Cópias mostram velocidade e tempo restante; o aviso de conclusão tem o botão "Desfazer".

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
