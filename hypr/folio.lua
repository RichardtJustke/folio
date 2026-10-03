-- ~/.config/hypr/config/folio.lua  →  require("config/folio") no hyprland.lua
-- O blur global já está ligado em config/settings.lua (decoration.blur).

hl.window_rule({
	name = "folio",
	match = { class = "^folio$" },
	float = true,
	center = true,
	size = "1100 700",
	rounding = 14, -- igual ao Theme.radius do app
	border_size = 0,
	no_shadow = true,
})

hl.bind((_G.mainMod or "SUPER") .. " + E", hl.dsp.exec_cmd("folio"))
