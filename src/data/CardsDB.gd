class_name CardsDB
extends RefCounted

## Steam trading cards data (GDD §11). These are display-only in-game; actual
## card collection is handled by Steam. This DB powers the Cards tab viewer.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, CURSED }

const CARDS: Array = [
	{"number": "3", "rarity": Rarity.COMMON, "desc": "'3' in monospace, white on dark", "bg_color": "#1a1a1a", "dlc": false},
	{"number": "14", "rarity": Rarity.COMMON, "desc": "'14' in monospace, white on dark", "bg_color": "#1a1a1a", "dlc": false},
	{"number": "42", "rarity": Rarity.UNCOMMON, "desc": "'42' in monospace, blue glow", "bg_color": "#0a1a3a", "dlc": false},
	{"number": "69", "rarity": Rarity.UNCOMMON, "desc": "'69' in monospace, pink glow", "bg_color": "#2a0a1a", "dlc": false},
	{"number": "7", "rarity": Rarity.RARE, "desc": "'7' in monospace, LARGE, gold glow, pulsing", "bg_color": "#1a1500", "dlc": false},
	{"number": "100", "rarity": Rarity.COMMON, "desc": "'100' in monospace, white on dark", "bg_color": "#1a1a1a", "dlc": false},
	{"number": "\u221e", "rarity": Rarity.LEGENDARY, "desc": "'\u221e' in monospace, magenta glow", "bg_color": "#1a0a2a", "dlc": false},
	{"number": "0", "rarity": Rarity.CURSED, "desc": "'0' in monospace, red, inverted colors", "bg_color": "#1a0000", "dlc": false},
	{"number": "$4.99", "rarity": Rarity.COMMON, "desc": "'$4.99' in monospace, wallet icon", "bg_color": "#1a1a1a", "dlc": true},
]

static func rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.CURSED: return "Cursed"
		_: return "Unknown"

static func rarity_color(r: int) -> Color:
	match r:
		Rarity.COMMON: return Color("#888888")
		Rarity.UNCOMMON: return Color("#44aaff")
		Rarity.RARE: return Color("#ffaa00")
		Rarity.LEGENDARY: return Color("#ff44ff")
		Rarity.CURSED: return Color("#ff4444")
		_: return Color("#888888")
