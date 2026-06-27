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

- Renamed product to **NeatWhisky**; changed bundle identifiers to `app.neatwhisky*`;
  repointed in-app website/GitHub links to the NeatWhisky repository.
- Targets a modern **Wine Staging 11.x** build instead of Wine 7.7: bumped the
  default bottle Wine version to 11.10.0, added a `wine64 -> wine` compatibility
  shim created on install, and made `Wine.wineBinary` resolve `wine64`-or-`wine`
  at runtime so WoW64 builds work. Added `Wine.bootUpdate(bottle:)` (`wineboot -u`)
  and wired it into the install/upgrade flow via
  `WhiskyWineInstaller.updateExistingBottles()` (called after install) so existing
  bottles' prefixes are refreshed after a Wine upgrade.
- Switched the `WhiskyKit` Swift package dependency URL from SSH to HTTPS so the
  package and CI build without requiring an SSH key.
- **Unified, mirror-aware download layer** (`DownloadSources`): every network
  asset (Wine build, Steam installer, winetricks) is fetched through switchable
  mirrors (official / China / global) with automatic failover, including
  mainland-China mirrors (gh-proxy.com / ghfast.top) for the large Wine tarball
  + version manifest. `WhiskyWineSource` is now a thin facade over it.
- **Full open-source graphics stack** (`GraphicsStack`): Wine + DXVK + MoltenVK,
  with DXVK enabled by default for new bottles. NeatWhisky does **not** bundle
  GPTK / CrossOver components.
- **Recipe engine** (`AppRecipe` + `RecipeTools`): a per-app fix framework with
  `detect / apply / repair / status`, plus reusable helpers (winetricks, registry,
  file install, launch-argument/locale configuration) built on `Wine`. Recipes can
  declare a `minimumWineVersion`; the engine (`RecipeTools.ensureWineVersion`)
  upgrades the bundled Wine on demand before applying. `SteamRecipe` requires
  Wine ≥ 11.0.0.
- **`SteamRecipe`** implementing the Steam fixes as a recipe:
  - CJK fonts via `winetricks cjkfonts` + registry font fallback (fixes 乱码);
  - the `steamwebhelper` wrapper (bundled in the app) forcing CEF into
    `--disable-gpu --single-process` inside a Job Object (fixes the black window
    and the close/restart loop), with backup/restore-aware injection;
  - launch arguments (`-cef-disable-gpu -cef-disable-gpu-compositing
    -noverifyfiles`) and a CJK-aware locale written to `ProgramSettings`.
- **One-click `SteamBootstrapper`**: verifies macOS, ensures Wine + Rosetta 2,
  creates a dedicated Steam bottle, downloads and silently installs the latest
  official Steam (`SteamSetup.exe /S`), applies the Steam fixes, reports progress,
  and rolls back the bottle on failure.
- **Onboarding wizard UI** (`SteamSetupWizardView` + `SteamSetupViewModel`): a
  first-run "开箱向导" with one-tap start, live progress and a done/error state,
  plus a download-mirror selector; entry points added to the main window and the
  empty state.
- **Bottle-detail Steam section** (`SteamFixView`): shows recipe status and a
  one-tap "一键适配 / 重新修复" action.
- **Launch-time self-heal**: `RecipeRegistry.selfHeal` runs before every program
  launch (hooked into `Program.runInWine`), re-injecting the Steam wrapper if a
  Steam update reverted it.
- **Release pipeline** (`.github/workflows/Release.yml`): builds, optionally
  Developer ID-signs + notarizes, packages a DMG and attaches it to the GitHub
  Release (degrades to an unsigned build without secrets); plus a Homebrew Cask
  template (`homebrew/neatwhisky.rb`) that the workflow auto-bumps (version +
  sha256, pushed to the tap) when `HOMEBREW_TAP_TOKEN` is configured.
- **Unit tests** (`WhiskyKit/Tests/WhiskyKitTests`): Swift Testing coverage for
  the mirror catalog/failover ordering, the recipe metadata (minimum Wine
  version, launch arguments, CEF dirs), the open-source graphics-stack
  invariants and bottle path resolution. Swift Testing runs via `swift test`
  with a bare swift.org toolchain (no full Xcode required).

## Upstream credits & acknowledgments

NeatWhisky stands on the shoulders of Whisky and the broader Wine-on-Mac ecosystem:

- Whisky by Isaac Marovitz, ohaiibuzzle, and contributors
- [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) by Gcenx and doitsujin
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) by KhronosGroup
- [msync](https://github.com/marzent/wine-msync) by marzent
- [Sparkle](https://github.com/sparkle-project/Sparkle), [SemanticVersion](https://github.com/SwiftPackageIndex/SemanticVersion),
  [swift-argument-parser](https://github.com/apple/swift-argument-parser), [SwiftyTextTable](https://github.com/scottrhoyt/SwiftyTextTable)
- WineHQ and CodeWeavers, whose work underpins Wine on macOS
