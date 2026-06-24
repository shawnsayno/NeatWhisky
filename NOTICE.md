# NOTICE

NeatWhisky is a fork of **Whisky** (https://github.com/Whisky-App/Whisky),
created by Isaac Marovitz and contributors, which was archived in May 2025.

Whisky is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.
NeatWhisky is a derivative work and is therefore **also licensed under GPL-3.0**.
The full license text is in [`LICENSE`](LICENSE).

## Why this fork exists

The upstream maintainer explicitly stated that WhiskyWine would not be upgraded
past Wine 7.7, and that "fixes for specific apps and games, like Steam, will not
be produced." NeatWhisky exists to close exactly that gap, with a focus on a
zero-to-playing, one-click experience for Steam on Apple Silicon.

## Summary of changes relative to upstream Whisky v2.3.5

This list is maintained for GPL-3.0 compliance (§5: "carry prominent notices
stating that you modified it"). It will grow as milestones land.

- Renamed product to **NeatWhisky**; changed bundle identifiers to `app.neatwhisky*`.
- (Planned) Bundle a modern Wine Staging 11.x build instead of Wine 7.7, with a
  `wine64 -> wine` compatibility shim for WoW64 builds.
- (Planned) Full open-source graphics stack only (Wine + DXVK + MoltenVK);
  NeatWhisky does **not** bundle GPTK / CrossOver components.
- Added a **Steam fix** layer (`SteamFix/`): a `steamwebhelper` wrapper that
  forces CEF into `--disable-gpu --single-process` (fixes the CEF 126 black-window
  bug) and is wrapped in a Job Object (fixes the close/restart loop), plus CJK
  font installation and launch-argument configuration.
- (Planned) A one-click Bootstrapper: Rosetta 2, dependency setup, automatic
  download + silent install of the latest Steam, and automatic application of fixes.

## Upstream credits & acknowledgments

NeatWhisky stands on the shoulders of Whisky and the broader Wine-on-Mac ecosystem:

- Whisky by Isaac Marovitz, ohaiibuzzle, and contributors
- [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) by Gcenx and doitsujin
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) by KhronosGroup
- [msync](https://github.com/marzent/wine-msync) by marzent
- [Sparkle](https://github.com/sparkle-project/Sparkle), [SemanticVersion](https://github.com/SwiftPackageIndex/SemanticVersion),
  [swift-argument-parser](https://github.com/apple/swift-argument-parser), [SwiftyTextTable](https://github.com/scottrhoyt/SwiftyTextTable)
- WineHQ and CodeWeavers, whose work underpins Wine on macOS
