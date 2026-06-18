# Workshop Pack Format

Community meme packs for NUMBER GOES UP. These replace funny number popups,
sounds, music stems, and UI textures with community-created content.

**We are not responsible for what the community does with this.**

## Pack structure

```
pack.json           (required — manifest)
popups/             (optional — pattern ID → image/video)
  80085.png
  69.webm
  420.webp
  ...
sounds/             (optional — event/pattern ID → audio)
  80085.ogg
  prestige.ogg
  click.ogg
  ...
music/              (optional — stem overrides)
  pad.ogg
  bass.ogg
  arp.ogg
  full.ogg
overrides/          (optional — UI texture overrides)
  red_button_bg.png
  wallet_icon.png
  number_bg.png
```

## pack.json

```json
{
  "name": "Anime Was A Mistake",
  "author": "degenerateNumberFan",
  "version": "1.0",
  "priority": 100,
  "description": "Calculator jokes but anime. You know exactly what this means."
}
```

| Field     | Type   | Required | Description                                    |
|-----------|--------|----------|------------------------------------------------|
| name      | string | yes      | Display name of the pack                       |
| author    | string | yes      | Creator name                                   |
| version   | string | yes      | Semantic version (e.g. "1.0")                  |
| priority  | int    | no       | Higher = checked first (default 0)             |
| description | string | no      | Optional description shown in the Workshop UI  |

## Supported file formats

### Popups (funny number images/videos)
| Format | Extension | Type    | Notes                                     |
|--------|-----------|---------|-------------------------------------------|
| PNG    | .png      | static  | Most compatible. Use for static images.   |
| WebP   | .webp     | static  | Smaller files, full alpha support.         |
| JPEG   | .jpg/.jpeg| static  | Use only for photos (no transparency).     |
| WebM   | .webm     | animated| **Convert GIFs to WebM.** Godot can't decode GIF. |
| OGV    | .ogv      | animated| Theora video. Alternative to WebM.         |

### Sounds
| Format | Extension | Notes                                    |
|--------|-----------|------------------------------------------|
| OGG    | .ogg      | **Recommended.** Best compression/quality. |
| WAV    | .wav      | Uncompressed, larger files.              |
| MP3    | .mp3      | Supported but OGG is preferred.          |

### Music stems
Same formats as sounds. Stem IDs: `pad`, `bass`, `arp`, `full`.

### UI texture overrides
Same formats as popups (static only). Texture IDs:
- `red_button_bg` — background for the red button upgrade
- `wallet_icon` — the Heavy Wallet DLC icon
- `number_bg` — background behind the main number display

## Pattern IDs for popups/sounds

These map directly to the funny number registry (GDD §7.3):

| Pattern  | Label           |
|----------|-----------------|
| 5318008  | flip your phone |
| 8008135  | BOOBIES         |
| 42069    | ASCENDED        |
| 80085    | BOOBS           |
| 9001     | OVER 9000       |
| 1337     | LEET            |
| 2319     | WE GOT A 2319   |
| 666      | 666             |
| 777      | 777             |
| 8008     | BOOB            |
| 420      | 420             |
| 1738     | YEAH BABY       |
| 404      | NOT FOUND       |
| 1234     | 1234!           |
| 69       | 69              |
| 67       | 67              |

## Event IDs for sounds

| Event ID     | When it plays                          |
|--------------|----------------------------------------|
| click        | Number is clicked                      |
| buy          | Any upgrade purchased (except traps)   |
| buy_red      | Red button purchased                   |
| buy_slow     | Slow button purchased                  |
| buy_mystery  | Mystery button purchased               |
| prestige     | Prestige performed                     |
| ascension    | Ascension performed                    |
| transcendence| Transcendence performed                |
| offline      | Offline return toast                   |

Plus all pattern IDs above — these override the funny number stingers.

## Priority system

Packs stack. Higher priority = checked first. If pack A (priority 100) has
`80085.png` and pack B (priority 50) also has `80085.webm`, pack A wins for
pattern 80085. Pack B can still provide sounds or other patterns that A doesn't.

The player can reorder packs in the Workshop tab. Priority is saved per-pack.

## Converting GIFs to WebM

Godot cannot decode GIF at runtime. Convert animated GIFs to WebM:

```bash
ffmpeg -i input.gif -c:v libvpx-vp9 -b:v 0 -crf 40 output.webm
```

Or use any online GIF-to-WebM converter.

## Moderation

**We don't moderate packs.** Steam Workshop has its own moderation system.
If you see a pack that violates Steam's terms, report it through Steam.
We are not responsible for what the community creates.

The store page says: "Steam Workshop support. Community meme packs for funny
number popups. We are not responsible for what the community does with this."

## Creating a pack

1. Create a folder with your pack name (use underscores, no spaces)
2. Add a `pack.json` manifest
3. Add your files to the appropriate subdirectories
4. Test locally by placing the folder in:
   - Linux: `~/.local/share/godot/app_userdata/Number Goes Up/packs/`
   - Windows: `%APPDATA%/Godot/app_userdata/Number Goes Up/packs/`
   - macOS: `~/Library/Application Support/Godot/app_userdata/Number Goes Up/packs/`
5. When satisfied, publish to Steam Workshop from the in-game Workshop tab
