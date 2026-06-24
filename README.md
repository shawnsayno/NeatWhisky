<div align="center">

# NeatWhisky 🥃
**Zero to playing, one click — no terminal, no Wine knowledge.**

Run Steam on your Apple Silicon Mac. NeatWhisky sets everything up for you and
fixes the bugs that break Steam on a stock Wine setup.

English · [简体中文](README.zh-CN.md)

</div>

---

## What is NeatWhisky?

NeatWhisky is a maintained fork of the (now archived) [Whisky](https://github.com/Whisky-App/Whisky).
Whisky stopped at Wine 7.7 and its maintainer said app-specific fixes — like Steam —
would never be made. **NeatWhisky picks up exactly there.**

Its goal is simple: a complete beginner should be able to go from a fresh Mac to
**playing on Steam with a single click**, without ever touching a terminal or
learning what "Wine", "bottle", or "prefix" means.

## The problem it solves

On a stock modern-Wine setup, Steam on Apple Silicon is broken in several ways:

| Symptom | NeatWhisky |
| --- | --- |
| Garbled / missing Chinese (CJK) text | Fixed automatically |
| Crashes / `steamwebhelper` crash loop | Fixed (modern Wine) |
| Launches but the window is all black | Fixed (CEF single-process wrapper) |
| Can't be closed, keeps relaunching | Fixed (Job Object process management) |

## How it works (for you)

1. Download NeatWhisky and drag it to Applications.
2. Open it and click **Start**.
3. Watch the progress bar. NeatWhisky automatically:
   - checks your Mac and installs Rosetta 2 if needed,
   - sets up a modern Wine + open-source graphics stack (DXVK + MoltenVK),
   - creates a dedicated Steam environment,
   - **downloads and silently installs the latest Steam**,
   - applies all the fixes above.
4. Steam opens, in your language, not black, and closes normally.

> Heavy AAA 3D titles are out of scope of the "it just works" promise: NeatWhisky
> uses a fully open-source graphics stack and does not bundle Apple's Game Porting
> Toolkit or CrossOver components.

## Status

Early development. See the build plan in [`docs/`](docs/) and the technical
deep-dive in [`docs/how-it-works.html`](docs/how-it-works.html).

## Requirements

- Apple Silicon (M-series) Mac
- macOS Sonoma 14.0 or later

## License & attribution

NeatWhisky is a derivative of Whisky and is licensed under **GPL-3.0** (see
[`LICENSE`](LICENSE)). For the fork lineage and the list of changes relative to
upstream, see [`NOTICE.md`](NOTICE.md).
