class_name FunnyNumberDB
extends RefCounted

## Funny number registry (GDD §7.3). Patterns matched as substrings in the
## raw integer floor of the current number. Priority: longest pattern first,
## then explicit priority. Color is a hex string.

const REGISTRY: Array = [
	{"pattern": "5318008", "color": "#ff69b4", "label": "flip your phone", "size": 24, "priority": 13},
	{"pattern": "8008135", "color": "#ff69b4", "label": "BOOBIES", "size": 42, "priority": 12},
	{"pattern": "42069", "color": "#ff00ff", "label": "ASCENDED", "size": 44, "priority": 12},
	{"pattern": "80085", "color": "#ff69b4", "label": "BOOBS", "size": 38, "priority": 10},
	{"pattern": "9001", "color": "#ff8800", "label": "OVER 9000", "size": 34, "priority": 9},
	{"pattern": "1337", "color": "#00ffff", "label": "LEET", "size": 36, "priority": 8},
	{"pattern": "2319", "color": "#cc44ff", "label": "WE GOT A 2319", "size": 26, "priority": 7},
	{"pattern": "666", "color": "#ff2222", "label": "666", "size": 40, "priority": 7},
	{"pattern": "777", "color": "#ffffff", "label": "777", "size": 40, "priority": 7},
	{"pattern": "8008", "color": "#ff69b4", "label": "BOOB", "size": 34, "priority": 6},
	{"pattern": "420", "color": "#33cc33", "label": "420", "size": 36, "priority": 6},
	{"pattern": "1738", "color": "#ffdd00", "label": "YEAH BABY", "size": 32, "priority": 6},
	{"pattern": "404", "color": "#888888", "label": "NOT FOUND", "size": 32, "priority": 5},
	{"pattern": "1234", "color": "#ffaa00", "label": "1234!", "size": 32, "priority": 4},
	{"pattern": "69", "color": "#ff66cc", "label": "69", "size": 34, "priority": 3},
	{"pattern": "67", "color": "#44ff88", "label": "67", "size": 30, "priority": 2},
]

## Returns the highest-priority match for a digit string, or null.
static func match(digit_string: String) -> Variant:
	var best: Variant = null
	for entry in REGISTRY:
		if digit_string.find(entry.pattern) == -1:
			continue
		if best == null:
			best = entry
			continue
		var best_len: int = best.pattern.length()
		var entry_len: int = entry.pattern.length()
		if entry_len > best_len or (entry_len == best_len and entry.priority > best.priority):
			best = entry
	return best
