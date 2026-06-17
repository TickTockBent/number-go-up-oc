# NUMBER GOES UP — Agent Notes

Incremental/idle game per `NUMBER_GOES_UP_GDD.md`. Built in **Godot 4.6.3 (GDScript)**.
Greenfield; no pre-existing code. See GDD for design; this file is for engineering context.

## Engine binary

Godot is not system-installed. A self-contained binary lives in `tools/`:

```
tools/Godot_v4.6.3-stable_linux.x86_64
```

All commands below use it. The project root is the working directory.

## Commands

```bash
# Reimport/compile all scripts & resources (run after adding/renaming files):
./tools/Godot_v4.6.3-stable_linux.x86_64 --headless --import

# Run the headless test suite (86 tests; exits non-zero on failure):
./tools/Godot_v4.6.3-stable_linux.x86_64 --headless tests/TestRunner.tscn

# Run the actual game (needs a display; this is a headless box, so use a short quit):
./tools/Godot_v4.6.3-stable_linux.x86_64 --quit-after 3

# Open the editor (needs display):
./tools/Godot_v4.6.3-stable_linux.x86_64
```

There is no `lint`/`typecheck` step in Godot. `--import` is the closest compile check;
the test suite is the behavioral check. **Run both after non-trivial changes.**

The test runner sets `SaveSystem.save_enabled = false` so it never clobbers the real
player save (in `~/.local/share/godot/app_userdata/Number Goes Up/number_go_up.save`).

## Architecture

Single source of truth is the **GameState** autoload. UI reads via signals; nothing
stores derived values. Three autoloads (registered in `project.godot`):

- `GameState` (`src/autoload/GameState.gd`) — state, 20fps tick loop, multiplier math,
  purchases, prestige, ascension, transcendence. All multipliers are recomputed from
  upgrade counts, never stored.
- `SaveSystem` (`src/autoload/SaveSystem.gd`) — JSON save w/ SHA-256 checksum. The
  checksum exists *only* to trigger the GDD §9.3 "CHEATER" cosmetic penalty. No anti-cheat.
  Also syncs to Steam Cloud via SteamIntegration when available.
- `FunnyNumbers` (`src/autoload/FunnyNumbers.gd`) — polls the integer floor of the number,
  2.5s global cooldown, permanent sighting counts (never reset, even on transcendence).
- `SteamIntegration` (`src/autoload/SteamIntegration.gd`) — bridges game events to Steam
  via godot-steam (GDExtension). Detects the `Steam` class at runtime; no-ops gracefully
  when absent (headless, no GDExtension, no Steam client). Handles achievements, DLC
  detection (Heavy Wallet), and cloud save sync.

Static data (all `class_name`-registered globals, no preload needed):
- `UpgradeDB` (`src/data/UpgradeDB.gd`) — all 6 tiers as pure data via a general effect
  system. Effect types: `click_flat`, `rate_flat`, `click_mult`, `prod_mult`,
  `click_eq_rate`, `rate_pct_current`, `nothing`. Add a tier = add rows to `UPGRADES`.
- `FunnyNumberDB` (`src/data/FunnyNumberDB.gd`) — GDD §7.3 registry; longest-pattern-wins.
- `NumberFormatter` (`src/data/NumberFormatter.gd`) — the 4 notation modes (GDD §3.2).
  Notation is a gameplay-affecting choice (changes which funny numbers are visible).
- `AchievementsDB` (`src/data/AchievementsDB.gd`) — all 60 defined achievements (GDD §10;
  target is 67, chosen deliberately). Pure data; evaluation lives in SteamIntegration.

UI is built procedurally in `src/ui/Main.gd` (the `.tscn` is a near-empty Control) —
deliberate, to keep hand-authored scene files minimal and reviewable.

## Multiplier model (read before touching economy)

`production_mult()` folds, multiplicatively: `slow_mult` (persists through prestige,
resets only on ascension — GDD §6.1) × `prestige_mult` (1 + 0.02·level) ×
`ascension_mult` (1.1^level) × `transcendence_mult` (1 + 0.05·level) × heavy_wallet
(0.99999) × all `prod_mult` upgrades × **hidden mystery bonus** (1.00777^(mystery_count/7),
never displayed anywhere — GDD §5.7, the one secret).

`effective_rate() = base_rate() · production_mult()`, where `base_rate` sums `rate_flat`
upgrades plus `rate_pct_current` (the "recursive" Tier-6 upgrade = % of current number/s).

`click_value()`: if Click-of-God owned, = `effective_rate()`; else `click_power() · production_mult()`.

## Prestige layers (GDD §6)

Three nested reset loops, each resetting the layer below:

1. **Prestige** — unlock at 10K total earned. Resets number + upgrades + red/mystery counts.
   Reward: +2% production per level. `slow_mult` persists (suffer).
2. **Ascension** — unlock at prestige level 10. Resets everything prestige resets, plus
   prestige levels and `slow_mult` (finally cleared). Reward: ×1.1 production per level.
3. **Transcendence** — unlock at ascension level 5. Resets EVERYTHING except:
   transcendence counter, funny sightings, total clicks, settings, DLC, achievements.
   Reward: +5% production per level + permanent 30° hue shift of the number per level
   (wraps back to green at level 12).

## Steam integration

`SteamIntegration` is a 4th autoload that wraps godot-steam. It detects the `Steam`
class at runtime via `ClassDB.class_exists("Steam")` and no-ops all calls when absent.
This means the game runs identically with or without Steam — headless testing, non-Steam
builds, and dev machines without the GDExtension all work.

**The godot-steam GDExtension is not shipped prebuilt.** See
`addons/godotsteam/INSTALL.md` for compilation instructions. The `.gdextension` config
and folder structure are already in place; drop in the compiled binaries and Steam
activates automatically.

Achievement evaluation is data-driven: `AchievementsDB` defines all 60 achievements as
pure data; `SteamIntegration._evaluate_condition()` maps each `api_id` to a GameState
predicate. New achievements = add a row to `ACHIEVEMENTS` + a match case. Achievement
unlock state persists in `GameState.achievements_unlocked` (survives all resets).

## What's in this vertical slice

Done: number display + 4 notation modes, click + floating "+N", all 6 upgrade tiers
(data complete; mechanics general), all 3 prestige layers (prestige/ascension/transcendence)
with hue-shift color, save/load + checksum + CHEATER easter egg, funny-number detection
+ popups, slow-button persistence, red-button corruption tint, offline progress (8h cap),
mystery hidden bonus, Steam integration scaffold (achievements/DLC/cloud via godot-steam,
graceful degradation), 60 achievements defined + evaluated.

Not yet (later milestones): adaptive audio (GDD §12), controller/Deck mapping (§14),
settings UI, "You Win?" infinity edge case, Steam trading cards (requires Steam partner
config), remaining 7 achievements to reach the 67 target.

## Conventions

- No comments in code unless explaining a non-obvious *why* (per house style).
- Descriptive variable names (per house style).
- Godot 4 typed GDScript; `snake_case` for members, `PascalCase` for classes/nodes.
- Game state fits in <2KB JSON (GDD §15.3 budget) — keep `serialize()` lean.
