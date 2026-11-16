# IcoNVader - rebuild

**English** · [Italiano](README.it.md)

A restoration of the Mac screen saver **IcoNVader 3.0** (Daedale, 2004-2006), rebuilt from nothing
but its compiled binary. The original bundle, `IcoNVader.saver`, is kept exactly as it was
distributed and is never modified.

- **Try it in your browser:** https://robertodisanto.it/IcoNVader-rebuild/
- **Download the macOS screen saver:** [latest release](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest)

> **Disclaimer.** I am not the author of IcoNVader and I have no connection with Daedale.
> IcoNVader 3.0, its name, its icons and the original binary belong to their respective rights
> holders. This is a non-commercial hobby project, made out of nostalgia and for learning, to bring
> back a piece of software that is no longer distributed and no longer runs on today's Macs. If you
> are the rights holder and would prefer this material not to be published, please open an issue
> and I will remove it.

## Why this project

I remember it from when I was a kid: I used to watch it on an old Mac at home. Years later I found
it again, but it no longer opens: it was written for PowerPC and 32-bit Intel Macs, which macOS
stopped supporting long ago, and its source code was never released.

So I tried to rebuild it **with the help of AI**: starting from the binary alone, the AI helped me
disassemble it, understand class by class how each animation worked, and rewrite it from scratch,
first as a web page and then as a screen saver for today's Macs. The goal was to see it again
exactly as I remembered it, with the same formulas, the same timing and even the small quirks of
the original.

## The project

IcoNVader fills the screen with animated icons in six different ways: **Comets**, **Fireworks**,
**Game Of Life**, **Hypnosis**, **DNA** and **Jumpers**. The original no longer loads on macOS 10.15
(Catalina) or later, because it only contains 32-bit code.

Its behavior was recovered by reading the disassembled binary (constants, formulas, edge cases and
even the original's small bugs) and was rewritten twice:

- a **web version** (`web/iconvader/`), in JavaScript with Canvas 2D;
- a **screen saver for modern macOS** (`macos/`), in Swift, universal for Apple Silicon and Intel,
  macOS 11 or later.

The two versions produce **exactly** the same animation: given the same random number generator,
they yield the same positions, rotations, scales and opacities frame by frame
(`macos/Tests/compare.sh`).

The **options panel** is rebuilt from the original too: the three tabs (Appearance, Animation,
Advanced), the position of every control, the ranges and the default values all come from the
interface file inside the bundle. Like the original it is **in English and French**, with the
original wording, plus **Italian**.

### Web version

Published on GitHub Pages: **https://robertodisanto.it/IcoNVader-rebuild/**. The
**Pubblica su Pages** workflow updates it on every push to `main` that changes `web/`.

You can also open `web/iconvader/index.html` locally: no server or installation needed.

| Key | Action |
|---|---|
| **P** | open the options panel |
| **F** | full screen |
| **Space** or **N** | restart the animation (with "Random", picks a new one) |

The language follows your browser and can be changed in the **Advanced** tab.
Useful URL parameters: `?behavior=DNA&icons=Daedale&lang=fr`
(behaviors: `Comets`, `Fireworks`, `GameOfLife`, `Hypnosis`, `DNA`, `Jumpers`;
icon sets: `Christmas`, `Daedale`; languages: `en`, `fr`, `it`).

### macOS screen saver

**Download.** From the [releases page](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest)
download [`IcoNVader-saver.zip`](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest/download/IcoNVader-saver.zip).

To build a new one with GitHub Actions:

1. go to **Actions → Compila salvaschermo macOS → Run workflow**;
2. when it finishes, download the **IcoNVader-saver** artifact (it contains `IcoNVader-saver.zip`).

If you tick **release** (and enter a **tag**, for example `v3.0.3`), the zip is also published as a
GitHub release. The **screenshot** artifact contains a picture of every behavior and of every tab of
the options panel, in every language, taken during the automated test.

**Install.** Unzip it and double-click `IcoNVader.saver`: it is installed for the current user
in `~/Library/Screen Savers/`. Then pick it in **System Settings → Screen Saver**; the **Options**
button opens the panel in your system language.

The release notes say whether that build is signed with a Developer ID and notarized by Apple. If it
is not (ad-hoc signature), macOS blocks it the first time; remove the quarantine flag before
installing:

```bash
xattr -dr com.apple.quarantine ~/Downloads/IcoNVader.saver
```

**Updating.** macOS keeps the previous version loaded until the screen saver process restarts. After
installing a new version, close System Settings and run:

```bash
killall legacyScreenSaver
```

**Signing (maintainers).** The build workflow signs and notarizes the bundle when the repository
has the Developer ID certificate and an App Store Connect API key as secrets; see
[`docs/firma-macos.md`](docs/firma-macos.md) (in Italian).

**Custom icon sets.** Just like the original, create a folder of `.icns` or `.png` files in
`~/Library/Application Support/IcoNVader/Icon Sets/<Set name>/` and it will show up in the
**Icons** menu of the panel.

**Build it locally** (requires Xcode):

```bash
brew install xcodegen
```

```bash
cd macos && xcodegen generate && open IcoNVader.xcodeproj
```

## Repository layout

```
IcoNVader.saver/                 original bundle (unmodified)
docs/iconvader/                  reverse engineering: architecture, preferences, method (Italian)
docs/iconvader/comportamenti/    detailed pseudocode of every behavior (English)
i18n/stringhe.json               English, French and Italian strings (single source)
web/iconvader/                   web version
macos/Sources/Core/              Swift core (Foundation only, also builds on Linux)
macos/Sources/Saver/             ScreenSaver view, drawing and options panel (AppKit)
macos/Resources/                 macOS translations (generated)
macos/Tests/                     Swift/JS comparison and test of the compiled bundle
tools/                           annotated disassembly, icons and translations
.github/workflows/               macOS build (manual) and Pages publishing
```

## Learn more

[`docs/iconvader/README.md`](docs/iconvader/README.md) (in Italian) explains how the reverse
engineering was done: the binary format, how to make the disassembly readable, the architecture of
the original, its options and the quirks that were kept on purpose.

```bash
tools/reversing/disassembla.sh     # annotated disassembly in build/reversing/ (needs llvm-objdump)
```

```bash
macos/Tests/compare.sh             # Swift vs JavaScript comparison (needs swiftc and node)
```

```bash
python3 tools/genera_traduzioni.py # regenerate translations from i18n/stringhe.json
```

## Legal notes

IcoNVader 3.0 is © 2004-2006 Daedale. This repository is not affiliated with or endorsed by
Daedale. It is an educational preservation project for software that is no longer distributed or
maintained: the binary and the icons included are those of the original package and remain the
property of their respective owners. The code of the rebuild (web version, macOS screen saver and
tools) was written from scratch and contains no code from the original.

## License

The code and documentation of the rebuild are released under the **MIT** license
(see [`LICENSE`](LICENSE)). The license does **not** apply to the original Daedale material: the
`IcoNVader.saver` bundle, its binary, icons and images, including their copies and conversions
(`web/iconvader/icons/` and the icons bundled in the compiled screen saver).
