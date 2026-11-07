-- ~/.config/hypr/config/folio.lua  →  require("config/folio") no hyprland.lua
-- O Folio abre como qualquer app: tiling, respeitando layout e hierarquia de janelas.
-- (Para voltar a flutuar: float = true, center = true, size = "1100 700".)

hl.window_rule({
	name = "folio",
	match = { class = "^folio$" },
	rounding = 14, -- igual ao Theme.radius padrão do app
})

-- Seletor de arquivos ("Abrir"/"Salvar como" dos apps, com o Folio como portal): flutua no centro
hl.window_rule({
	name = "folio-picker",
	match = { class = "^folio-picker$" },
	float = true,
	center = true,
	size = "960 620",
	rounding = 14,
})

-- Caminho absoluto: o PATH do Hyprland não inclui ~/.local/bin (com "folio" o atalho não abre nada).
-- Se o SUPER+E já estiver no seu keybinds, apague esta linha: bind duplicado abre duas janelas.
hl.bind((_G.mainMod or "SUPER") .. " + E", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/folio"))
