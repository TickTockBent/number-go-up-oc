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

# Run the headless test suite (44 tests; exits non-zero on failure):
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
  purchases, prestige. All multipliers are recomputed from upgrade counts, never stored.
- `SaveSystem` (`src/autoload/SaveSystem.gd`) — JSON save w/ SHA-256 checksum. The
  checksum exists *only* to trigger the GDD §9.3 "CHEATER" cosmetic penalty. No anti-cheat.
- `FunnyNumbers` (`src/autoload/FunnyNumbers.gd`) — polls the integer floor of the number,
  2.5s global cooldown, permanent sighting counts (never reset, even on transcendence).

Static data (all `class_name`-registered globals, no preload needed):
- `UpgradeDB` (`src/data/UpgradeDB.gd`) — all 6 tiers as pure data via a general effect
  system. Effect types: `click_flat`, `rate_flat`, `click_mult`, `prod_mult`,
  `click_eq_rate`, `rate_pct_current`, `nothing`. Add a tier = add rows to `UPGRADES`.
- `FunnyNumberDB` (`src/data/FunnyNumberDB.gd`) — GDD §7.3 registry; longest-pattern-wins.
- `NumberFormatter` (`src/data/NumberFormatter.gd`) — the 4 notation modes (GDD §3.2).
  Notation is a gameplay-affecting choice (changes which funny numbers are visible).

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

## What's in this vertical slice

Done: number display + 4 notation modes, click + floating "+N", all 6 upgrade tiers
(data complete; mechanics general), Layer-1 prestige, save/load + checksum + CHEATER
easter egg, funny-number detection + popups, slow-button persistence, red-button
corruption tint, offline progress (8h cap), mystery hidden bonus.

Not yet (later milestones): ascension & transcendence layers, Steam integration
(achievements/cloud/DLC/trading cards via godot-steam), adaptive audio (GDD §12),
controller/Deck mapping (§14), settings UI, achievements system, save-corruption
achievement wiring, "You Win?" infinity edge case.

## Conventions

- No comments in code unless explaining a non-obvious *why* (per house style).
- Descriptive variable names (per house style).
- Godot 4 typed GDScript; `snake_case` for members, `PascalCase` for classes/nodes.
- Game state fits in <2KB JSON (GDD §15.3 budget) — keep `serialize()` lean.
