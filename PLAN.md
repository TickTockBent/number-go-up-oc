# NUMBER GOES UP — Implementation Plan

**Status:** Active
**Last updated:** Phase 1 starting

---

## Current state audit

**Done (working, tested — 86 tests passing):** Core loop, 6 upgrade tiers, 3 prestige
layers (prestige/ascension/transcendence with hue-shift color), 4 notation modes, funny
number detection, save/load + SHA-256 checksum + CHEATER easter egg, offline progress
(8h cap), mystery hidden bonus, Steam integration scaffold (graceful degradation, 60
achievements defined + evaluated), red-button number tint at 6+, slow-button persistence.

**GDD features not yet implemented:**
- Adaptive audio (§12) — the hardest piece
- Controller/Deck mapping (§14)
- Settings UI (§13)
- "You Win?" infinity edge case (§15.2)
- Trading cards (§11) — requires Steam partner config, out of our hands
- 7 unspecified achievements (GDD defines 60, says 67; "You Win?" is 1, remaining 6 TBD)

**Wiring gaps (systems built but surfaces missing):**
- Red-button corruption only tints the number — no escalating UI corruption (20+ tint, 50+ everything red)
- Heavy Wallet DLC — `bool` flag, no overlay/wallet icon/"ACCEPT YOUR FATE" screen
- Offline return — message label, not the GDD toast
- Stats tab, Cards tab — don't exist, blocking 3 achievements from ever firing
- Screen shake on high click power — not implemented

---

## Phase 1: Remaining GDD mechanics + wiring gaps

Fill in everything the GDD specifies that we're missing, so the spec is complete before
we layer Workshop on top.

### 1a. Red-button corruption escalation (§5.7)
- 6+ red: number turns red (done)
- 20+ red: entire UI develops red tint (overlay ColorRect with increasing opacity)
- 50+ red: everything is red — background, text, buy buttons. Game still works.
- Implementation: `Main.gd` watches `red_count`, applies a `ColorRect` overlay with
  computed red opacity. At 50+, also modulate all child Controls.

### 1b. Heavy Wallet DLC overlay (§8)
- Wallet icon (16×16) rendered left of the number, permanent
- "ACCEPT YOUR FATE" full-screen overlay on first detection
- Tooltip "$4.99" on hover
- `SteamIntegration._check_dlc()` already sets the flag; we just need the UI

### 1c. Offline return toast (§9.1)
- Proper toast panel (not a message label) with the GDD copy:
  "While you were gone, the number went up by [X]. It didn't miss you."
- Heavy Wallet second line: "(0.001% less than it would have been without the DLC.)"
- Auto-dismiss after a few seconds

### 1d. "You Win?" infinity edge case (§15.2)
- Detect `is_inf(number)` in display path
- Show "Infinity" + unlock hidden achievement "You Win?"
- Achievement added to AchievementsDB + evaluation case
- This is 1 of the 7 missing achievements (61/67 after this)

### 1e. Screen shake (§4.1)
- 10K+/click: subtle shake
- 1M+/click: violent shake + background flicker
- Settings toggle: On / Off / MAXIMUM (§13.1)
- Implementation: `Camera2D` shake or direct `offset` tween on the root

### 1f. Remaining 6 achievements — ON HOLD
- GDD says 67 ("chosen deliberately") but only enumerates 60.
- "You Win?" (1d above) brings us to 61.
- **The other 6 will be provided by the game owner at a later date.**
- `AchievementsDB` count test currently asserts 60; will bump as achievements are added.

---

## Phase 2: Settings UI + Stats + Cards tabs

Unblocks achievements and gives Workshop a home in the UI.

### 2a. Tab system
- Currently one screen. Add a tab bar: Game / Stats / Cards / Settings / Workshop
- Workshop tab populated in Phase 4
- Tab switching shouldn't pause the tick loop

### 2b. Settings UI (§13)
- Notation Mode (Normal Person / Number Enjoyer / Unhinged / Nerd) — gameplay-affecting
- Offline Progress toggle (On/Off)
- Screen Shake (On / Off / MAXIMUM)
- Funny Number Popups toggle (On/Off)
- Number Color Override (locked unless 1+ transcendence; manual hue selection)
- Volume sliders: Master / Music / SFX / Funny Number Stinger (§13.2)
- Accessibility: Reduced Motion, High Contrast, Auto-Click, Colorblind modes (§13.3)
  — defer most accessibility to Phase 5 unless trivial
- Unlocks "Notation Nerd" and "Unhinged Mode" achievements (already evaluated, just
  need the surface)

### 2c. Stats tab (§7.5)
- Funny Number Sightings section: each pattern's color, label, total sighting count
  (never resets, even on transcendence)
- Total clicks, playtime, prestige/ascension/transcendence levels, current rate
- Track `_stats_tab_open_seconds` for "The Long Stare" achievement (2 min stare, no input)

### 2d. Cards tab (§11)
- Display the 8 base cards + 1 DLC card as a grid
- Can't actually collect them here (Steam handles that) — just a viewer
- Card data: number, rarity, card art description, background color
- Unlocks "Card Collector" achievement on open

---

## Phase 3: Audio system (synthesized placeholders)

Audio assets will be **synthesized placeholders** using Godot's `AudioStreamGenerator`.
The system is built fully; real audio files replace synthesized ones later by swapping
files in `audio/`. No external assets sourced.

### 3a. SFX (§12.2) — do first
- Click: soft mechanical click, pitch varies ±5% randomly
- Buy upgrade: cash register "cha-ching," pitch scaled to cost
- Buy red button: same click but "red" (same sound, joke)
- Buy slow button: descending slide whistle
- Buy mystery button: static burst, 0.2s
- Prestige: ascending chime sequence, ethereal reverb
- Ascension: same chime, reversed, then forward
- Transcendence: a single bass note
- Offline return toast: gentle "ping"
- Funny number stingers (§7.4): synth chirp in popup's color-appropriate key, with
  special cases:
  - 69: single voice sample "Nice." (synthesized tone placeholder)
  - OVER 9000: distorted scream, 0.3s, clipped (synthesized noise burst)
  - 666: reversed piano chord (synthesized, reversed)
  - 420: chill lo-fi hit with vinyl crackle (synthesized)
  - BOOBS/BOOBIES/BOOB: calculator beep sequence (ascending)
  - WE GOT A 2319: alarm klaxon, 0.5s
- Implementation: `AudioStreamPlayer` pool, one per category. Synthesized tones via
  `AudioStreamGenerator` producing `AudioStreamWAV` or packed bytes.

### 3b. Adaptive music (§12.1) — the ambitious part
**Stem layering approach:** 4 synthesized loopable stems crossfaded by production rate.
- Stem 1 (pad): always on, base state — minimal, soft, nearly subliminal
- Stem 2 (bass pulse): fades in at 1K+/s
- Stem 3 (arpeggiated synth): fades in at 100K+/s
- Stem 4 (full mix / drums): fades in at 10M+/s — "the track is actually a banger now"
- Each stem: looping `AudioStreamPlayer` on its own bus; volume crossfaded via Tween
- Post-prestige (30s): mute all but stem 1 (single held note), then rebuild matching
  new production rate
- Red 20+: master music bus pitch shift (detune); 50+: more shift, noticeably off-key
- 99% slow: music slows to half speed, bass drops an octave
- Implementation: 4 `AudioStreamPlayer`s on a "Music" bus. `Main.gd` watches
  `effective_rate()` and `red_count`/`slow_mult`, triggers crossfades.

### 3c. Volume controls
- 4 buses: Master, Music, SFX, Stinger (separate per §13.2)
- Sliders in Settings UI (from 2b)
- Defaults: Master 100%, Music 80%, SFX 100%, Stinger 100%

---

## Phase 4: Workshop integration (full system)

The platform feature. Godot earns its keep here — runtime asset loading from Workshop
folders is trivial compared to Electron with Steam Workshop API bindings.

**Pack format:** PNG/WebP static + WebM animated. No GIF (Godot can't decode at runtime).
Pack creators convert GIFs to WebM. Documented in pack format docs.

### 4a. Pack format spec

```
pack.json
├── name: "Anime Was A Mistake"
├── author: "degenerateNumberFan"
├── version: "1.0"
├── priority: 100                    # higher = checked first
├── popups/                          # pattern ID → image/video
│   ├── 80085.png                    # static image
│   ├── 69.webm                      # animated (VideoStreamPlayer)
│   ├── 420.webp                     # static (WebP supported)
│   └── ...
├── sounds/                          # event/pattern ID → audio
│   ├── 80085.ogg
│   ├── prestige.ogg
│   ├── click.ogg
│   └── ...
├── music/                           # optional stem overrides
│   ├── pad.ogg
│   ├── bass.ogg
│   ├── arp.ogg
│   └── full.ogg
└── overrides/                       # UI texture overrides
    ├── red_button_bg.png
    ├── wallet_icon.png
    └── number_bg.png
```

Pattern ID maps to filename. If a pack has `80085.png`, it replaces the text popup
with the image. If it has `80085.ogg`, it replaces the stinger. No file for a pattern?
Falls back to default. Packs stack with a priority order — an anime pack handles
calculator jokes while a Seinfeld pack handles prestige quotes.

### 4b. Pack resolution system — `WorkshopManager` autoload
- Scans Workshop folder for installed packs
- Reads each `pack.json`, builds a registry:
  `{pattern_id → [{pack, file}, ...]}` sorted by priority
- `resolve_popup(pattern_id)` → first matching file (highest priority pack that has it),
  or null (fall back to default text popup)
- `resolve_sound(event_id)` → same pattern for audio
- `resolve_override(texture_id)` → same for UI textures
- `resolve_music_stem(stem_id)` → optional stem override
- Player configures pack priority order in Workshop tab; stored in settings

### 4c. Runtime asset loading
- Images: `Image.load(absolute_path)` → `ImageTexture` → display in `TextureRect`
- Video: `VideoStreamPlayer` with `stream = load(absolute_path)` (Theora .ogv / .webm)
- Audio: read file bytes → `AudioStreamMP3.new()` with `data` field, or
  `AudioStreamOggVorbis` from file
- All loaded lazily, cached per pack

### 4d. Workshop UI tab
- List installed packs with enable/disable toggles
- Priority reorder (drag or up/down buttons)
- "Browse Workshop" button → opens Steam overlay to Workshop page
- Pack preview (name, author, sample popup image)

### 4e. Steam Workshop API integration (via godot-steam)
- `Steam.publishWorkshopFile()` — upload packs from in-game (or external tool)
- `Steam.subscribeItem()` / `Steam.unsubscribeItem()` — subscribe/unsubscribe
- `Steam.getSubscribedItems()` + `Steam.getItemInstallInfo()` — enumerate installed packs
- `steam_workshop_item_downloaded` callback → refresh pack list
- Workshop tags: "Meme", "Anime", "Sound", "NSFW" (Steam's moderation handles NSFW)
- All no-ops gracefully when Steam unavailable (same pattern as SteamIntegration)

### 4f. The unmoderated stance
- Store page disclaimer: "Steam Workshop support. Community meme packs for funny
  number popups. We are not responsible for what the community does with this."
- No in-game moderation — rely entirely on Steam Workshop's reporting system
- Pack loading is opt-in (player must subscribe + enable)
- We do not moderate. We can't. Steam Workshop has its own moderation.

---

## Phase 5: Polish

- Post-prestige golden flash (10s, partially done)
- Slow penalty visual lag (trailing ghost effect on digits, as if dragging)
- Unhinged mode layout chaos (number pushes other elements, doesn't care about layout)
- Controller/Deck mapping (§14):
  - A-button = click, D-pad/left stick = navigate upgrades
  - Right trigger = rapid-click hold (10 clicks/s)
  - Left trigger = tab switcher
  - L4 = prestige (with confirmation), R4 = buy best affordable upgrade
- Steam Deck back grips
- Sales milestone upgrades (§17): "You Shouldn't Have" at 100K/1M copies sold
- Accessibility (§13.3): Reduced Motion, High Contrast, Screen Reader announcements,
  Auto-Click, Colorblind modes — defer non-trivial ones here

---

## Decisions locked

| Decision | Choice |
|----------|--------|
| Engine | Godot 4.6.3 (GDScript) |
| Animated Workshop format | PNG/WebP static + WebM animated (no GIF) |
| Audio assets | Synthesize placeholders now, replace later |
| Remaining 6 achievements | On hold — owner will provide |
| Workshop scope (first pass) | Full system: pack loading + Steam Workshop API |
| Execution order | Phases in order: 1 → 2 → 3 → 4 → 5 |

---

## Out of scope (for now)

- Trading cards (§11) — requires Steam partner config, not implementable without it
- "Realms" — mentioned by owner as future feature; not scoped yet
- The remaining 6 achievements — owner will provide specs later

---

*This plan goes up.*
