# GodotSteam GDExtension binaries

This folder contains the godot-steam GDExtension config. The actual platform
binaries (.so/.dll/.dylib + steam_api libs) are **not included** because:

1. GodotSteam does not distribute prebuilt GDExtension binaries — they must be
   compiled from source.
2. The Steamworks SDK (required to compile) requires a Valve partner account.
3. Binaries are large and platform-specific.

## To install (enables Steam functionality):

Follow the [GodotSteam GDExtension compile guide](https://godotsteam.com/howto/gdextension/).
After compiling, copy the binaries here:

```
addons/godotsteam/
  godotsteam.gdextension          (already present)
  linux64/
    libgodotsteam.linuxbsd.template_debug.x86_64.so
    libgodotsteam.linuxbsd.template_release.x86_64.so
    libsteam_api.so               (from Steamworks SDK redistributable_bin/linux64/)
  win64/
    libgodotsteam.windows.template_debug.x86_64.dll
    libgodotsteam.windows.template_release.x86_64.dll
    steam_api64.dll               (from Steamworks SDK redistributable_bin/win64/)
  osx/
    libgodotsteam.macos.template_debug.universal.dylib
    libgodotsteam.macos.template_release.universal.dylib
    libsteam_api.dylib            (from Steamworks SDK redistributable_bin/osx/)
```

The game runs identically without these files — `SteamIntegration` detects
the `Steam` class at runtime and no-ops all Steam calls when absent. Drop the
binaries in and Steam functionality activates automatically.

## steam_appid.txt

Already present at the project root with app ID 480 (Valve's SpaceWar test app).
Replace with your real app ID before shipping. **Remove this file from the
final Steam build** — Valve recommends not shipping it.
