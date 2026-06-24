# SteamFix

The Steam-specific fix layer for NeatWhisky. These assets are applied to a Steam
bottle to fix the black-screen and close/restart-loop bugs of Steam's CEF 126
renderer under modern Wine on Apple Silicon.

## Contents

| File | Purpose |
| --- | --- |
| `steamwebhelper_wrapper.c` | Source of the `steamwebhelper` wrapper. Launches the real binary (renamed `steamwebhelper_orig.exe`) with `--disable-gpu --single-process` appended, inside a Job Object (`KILL_ON_JOB_CLOSE`). |
| `steamwebhelper_wrapper.exe` | Prebuilt PE32+ binary (cross-compiled with mingw-w64), bundled so end users don't need a compiler. CI rebuilds this from source. |
| `reapply-wrapper.sh` | Re-installs the wrapper into a bottle. Used to recover after a Steam update overwrites it. |

## How the wrapper fixes things

- **Black screen**: CEF 126 paints the browser window black under Wine 11. Forcing
  `--disable-gpu --single-process` sidesteps the bug. Steam does not forward these
  flags to its child, so the wrapper injects them.
- **Close/restart loop**: a naive wrapper leaves the real child orphaned on
  shutdown, so Steam relaunches it forever. The Job Object kills the child when the
  wrapper exits, giving a clean process lifecycle.

## Build

```bash
brew install mingw-w64
x86_64-w64-mingw32-gcc steamwebhelper_wrapper.c -o steamwebhelper_wrapper.exe -mwindows -O2 -municode
```

## Launch arguments paired with this fix

`-cef-disable-gpu -cef-disable-gpu-compositing -noverifyfiles`

`-noverifyfiles` stops Steam from restoring the original `steamwebhelper.exe` on launch.
