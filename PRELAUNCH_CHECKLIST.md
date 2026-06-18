# NUMBER GOES UP — Early Access Prelaunch Readiness Check

**Generated:** Jun 18 2026
**Tests:** 143 passing
**Commits:** 9
**GDD sections:** 17, all addressed

A critical bug was found and fixed during this audit: `_track_tab_activity()` was defined but never called from `_process()`, making 2 achievements (**The Long Stare**, **Card Collector**) permanently unobtainable. Stats tab also never refreshed on switch. Fixed and pushed (commit `3430f4e`).

---

## BLOCKERS — must fix before launch

- [ ] **1. Steam app ID is `480` (SpaceWar test app)** — `src/autoload/SteamIntegration.gd:8` + `steam_appid.txt`. Replace with real assigned app ID.
- [ ] **2. `HEAVY_WALLET_DLC_ID = 0`** — `src/autoload/SteamIntegration.gd:9`. DLC detection is inert until real DLC app ID assigned.
- [ ] **3. No `export_presets.cfg`** — Project cannot produce a shippable build. Must configure export presets in editor (Linux/Windows).
- [ ] **4. No `config/version` in `project.godot`** — Steam requires a version string for depot uploads.
- [ ] **5. godot-steam GDExtension binaries not compiled** — Scaffolding in place but `.so`/`.dll`/`.dylib` are gitignored. Export machine must have them or Steam silently falls back to offline mode. See `addons/godotsteam/INSTALL.md`.
- [ ] **6. No raster icons** — Only `icon.svg` (128×128). Steam store + Windows builds need PNG at 32/128/256/512 + `.ico`.

## SHOULD FIX — before or shortly after launch

- [ ] **7. Cloud save restore is one-directional** — `cloud_write` fires on every save, but `cloud_read`/`cloud_exists` are never called on launch. Cross-device sync only pushes local→cloud, never pulls cloud→local.
- [ ] **8. Stray `print()` debug logging** — `src/autoload/SteamIntegration.gd` (6 calls) and `src/autoload/WorkshopManager.gd` (4 calls) ship verbose logs to prod. Gate behind a debug flag or strip.
- [ ] **9. Gamepad button bindings may be wrong** — `gamepad_rapid_click` (button 7) and `gamepad_tab_switch` (button 6) map to stick-clicks, not triggers. The axis bindings (5/4) are correct; the button bindings are likely unintended. Verify on real Deck.
- [ ] **10. `GameState.deserialize` null-deref risk** — `data.get("upgrades", {}).duplicate(true)` — if a corrupt save stores explicit `null`, `.duplicate()` crashes. No type check before calling. (`src/autoload/GameState.gd:361-379`)
- [ ] **11. `AudioManager.gd:244` assumes `_stingers["_default"]` exists** — Fragile; if init order changes, crash before fallback can help.
- [ ] **12. WorkshopManager untyped Steam returns** — Lines 263-264, 285 call `.get()` on Dictionaries returned from dynamic Steam calls without type verification. Steam returning unexpected types could crash.

## NON-BLOCKING — acceptable for Early Access

- [ ] **13. Audio is synthesized placeholders** — Fully functional but not "real" assets. GDD-compliant; AGENTS.md documents this. Replace by swapping files in `audio/`. The Settings UI text says "audio system coming in Phase 3" — **stale copy, update it**.
- [ ] **14. §13.3 Accessibility entirely missing** — No Reduced Motion, High Contrast, Screen Reader, Auto-Click, or Colorblind modes. Largest GDD gap. Acceptable for EA if roadmapped.
- [ ] **15. §14 L4/R4 grip mappings missing** — Only A/RT/LT done. Prestige-on-L4 and buy-best-on-R4 not implemented.
- [ ] **16. §17 Sales milestone upgrade is stub-only** — `UpgradeDB.get_sales_count()` returns 0; upgrade not added to `UPGRADES` or shown in UI. Needs Steam stats integration.
- [ ] **17. Red-corruption digit flicker (§3.3)** — Color shift at 6+ is done, but the "gains a flicker" sub-effect is not.
- [ ] **18. No full-screen prestige overlay (§6.1)** — GDD says "full-screen overlay, tap to dismiss." Quotes only show in small message label.
- [ ] **19. Funny-number notation-aware popups (§7.1)** — Normal/Nerd modes should show smaller "[hidden in notation]" popups. All modes show identical popups.
- [ ] **20. Buy SFX pitch not scaled to cost (§12.2)** — Click pitch varies ±5%, but buy cha-ching pitch is fixed.
- [ ] **21. Ascension SFX missing reverse-then-forward (§12.2)** — Uses forward chime only.

## READY — no action needed

- [x] Core loop, 6 upgrade tiers, 3 prestige layers, 67 achievements — all implemented and tested
- [x] Save system (JSON + SHA-256 checksum + CHEATER penalty + offline 8h cap) — working
- [x] Funny number detection (16 patterns, 2.5s cooldown, permanent sightings) — working
- [x] Workshop system (pack scanning, priority resolution, Steam API graceful no-op) — working
- [x] GL Compatibility renderer (Steam Deck friendly), 1280×720, canvas_items stretch
- [x] Disk footprint ~2MB (excluding engine binary) — well under 50MB budget
- [x] Save path matches AGENTS.md documentation
- [x] 143 tests, all passing

---

## Recommended launch sequence

1. **Assign Steam app ID + DLC ID** → update `SteamIntegration.gd` constants + `steam_appid.txt`
2. **Compile godot-steam** → drop binaries into `addons/godotsteam/{linux64,win64,osx}/`
3. **Create export presets** → Linux + Windows (x86_64), PCK+EXE
4. **Add `config/version`** → e.g. `0.1.0` for EA
5. **Generate raster icons** → PNG 32/128/256/512 + ICO, update `project.godot`
6. **Wire cloud save restore** → call `cloud_read` on launch, compare timestamps
7. **Strip `print()` calls** or gate behind debug flag
8. **Update stale Settings UI copy** ("audio system coming in Phase 3")
9. **Upload build to Steam** → depot + branch + set live
