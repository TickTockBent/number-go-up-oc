# NUMBER GOES UP — Implementation Plan

**Status:** Phases 1–5 complete
**Last updated:** Phase 5 complete

---

## Current state audit

**Done (working, tested — 131 tests passing):** Core loop, 6 upgrade tiers, 3 prestige
layers (prestige/ascension/transcendence with hue-shift color), 4 notation modes, funny
number detection, save/load + SHA-256 checksum + CHEATER easter egg, offline progress
(8h cap), mystery hidden bonus, Steam integration scaffold (graceful degradation, 61
achievements defined + evaluated), red-button number tint at 6+ with escalation (20+ tint
overlay, 50+ everything red), slow-button persistence, Heavy Wallet DLC overlay +
"ACCEPT YOUR FATE" screen, offline return toast, "You Win?" infinity achievement, screen
shake (On/Off/MAXIMUM), TabContainer with Game/Stats/Cards/Settings/Workshop tabs, full
settings UI (notation, shake, toggles, 4 volume sliders, color override at transcendence
1+), Stats tab (funny sightings with color swatches, "The Long Stare" tracking), Cards
tab (8+1 card viewer, "Card Collector" achievement), full synthesized audio system
(AudioSynth + AudioManager: 4 adaptive music stems crossfaded by production rate,
post-prestige 30s cut, red detune, slow half-speed, SFX pool, click pitch variance,
funny-number stingers, Workshop sound overrides), Workshop integration (pack scanning,
priority-sorted resolution for popups/sounds/textures/music, Steam Workshop API with
graceful no-op, Workshop UI tab with enable/disable/reorder/browse), post-prestige
golden flash (10s fading), slow-penalty ghost trailing effect, Unhinged mode layout
chaos, controller/Deck mapping (A=click, R-trigger=rapid click, L-trigger=tab switch),
sales milestone upgrade stubs (GDD §17).

**GDD features not yet implemented:**
- Trading cards (§11) — requires Steam partner config, out of our hands
- 6 unspecified achievements (GDD defines 60, says 67; "You Win?" is 1, 61 done, 6 TBD
  — owner will provide specs)
- Real audio assets (synthesized placeholders in place; replace by swapping files)
- godot-steam GDExtension binaries (scaffolding in place; must compile from source)

---

## Phase 1: Remaining GDD mechanics + wiring gaps — COMPLETE

### 1a. Red-button corruption escalation (§5.7) — done
### 1b. Heavy Wallet DLC overlay (§8) — done
### 1c. Offline return toast (§9.1) — done
### 1d. "You Win?" infinity edge case (§15.2) — done (achievement 61/67)
### 1e. Screen shake (§4.1) — done (On/Off/MAXIMUM)
### 1f. Remaining 6 achievements — ON HOLD (owner will provide)

---

## Phase 2: Settings UI + Stats + Cards tabs — COMPLETE

### 2a. Tab system — done (Game/Stats/Cards/Settings/Workshop)
### 2b. Settings UI (§13) — done (notation, shake, toggles, 4 volume sliders, color override)
### 2c. Stats tab (§7.5) — done (funny sightings, "The Long Stare" tracking)
### 2d. Cards tab (§11) — done (8+1 cards, "Card Collector" achievement)

---

## Phase 3: Audio system (synthesized placeholders) — COMPLETE

### 3a. SFX (§12.2) — done (AudioSynth procedural generation, SFX pool, all events wired)
### 3b. Adaptive music (§12.1) — done (4 stems crossfaded by rate, post-prestige cut, red/slow effects)
### 3c. Volume controls — done (Master/Music/SFX/Stinger buses + sliders)

---

## Phase 4: Workshop integration (full system) — COMPLETE

### 4a. Pack format spec — done (`addons/WORKSHOP_PACK_FORMAT.md`)
### 4b. WorkshopManager autoload — done (scan, parse, priority-sorted resolution)
### 4c. Runtime asset loading — done (PNG/WebP, WebM/OGV, OGG)
### 4d. Workshop UI tab — done (enable/disable, reorder, browse)
### 4e. Steam Workshop API — done (subscribe/unsubscribe/publish, graceful no-op)
### 4f. Unmoderated stance — documented, store page disclaimer noted

---

## Phase 5: Polish — COMPLETE

- Post-prestige golden flash (10s fading from gold to base color) — done
- Slow penalty visual lag (trailing ghost digits at 20%+ slow) — done
- Unhinged mode layout chaos (upgrade rows jitter every 2s) — done
- Controller/Deck mapping (§14):
  - A-button / Space = click — done
  - Right trigger = rapid-click hold (10 clicks/s) — done
  - Left trigger = tab switcher — done
- Sales milestone upgrades (§17): stubs in UpgradeDB (`get_sales_count()`,
  `has_milestone_upgrade()`, `get_milestone_description()`) — done (returns 0; wired
  to real Steam stats in production)
- Accessibility (§13.3): Reduced Motion, High Contrast, Screen Reader, Auto-Click,
  Colorblind modes — deferred (non-trivial; not in this vertical slice)

---

## Decisions locked

| Decision | Choice |
|----------|--------|
| Engine | Godot 4.6.3 (GDScript) |
| Animated Workshop format | PNG/WebP static + WebM animated (no GIF) |
| Audio assets | Synthesize placeholders now, replace later |
| Remaining 6 achievements | On hold — owner will provide |
| Workshop scope (first pass) | Full system: pack loading + Steam Workshop API |
| Execution order | Phases in order: 1 → 2 → 3 → 4 → 5 (all complete) |

---

## Out of scope (for now)

- Trading cards (§11) — requires Steam partner config, not implementable without it
- "Realms" — mentioned by owner as future feature; not scoped yet
- The remaining 6 achievements — owner will provide specs later
- Real audio assets — synthesized placeholders in place
- godot-steam GDExtension binaries — must compile from source (see
  `addons/godotsteam/INSTALL.md`)
- Full accessibility suite (§13.3) — deferred

---

*This plan goes up.*
