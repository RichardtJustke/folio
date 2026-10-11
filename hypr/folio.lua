-- ~/.config/hypr/config/folio.lua  →  require("config/folio") no hyprland.lua
-- O Folio abre como qualquer app: tiling, respeitando layout e hierarquia de janelas.
-- (Para voltar a flutuar: float = true, center = true, size = "1100 700".)

hl.window_rule({
	name = "folio",
	match = { class = "^folio$" },
	rounding = 14, -- igual ao Theme.radius padrão do app
})

hl.bind((_G.mainMod or "SUPER") .. " + E", hl.dsp.exec_cmd("folio"))
