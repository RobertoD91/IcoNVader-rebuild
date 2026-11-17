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

## Install on macOS

1. Download `IcoNVader-saver.zip` from the [latest release](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest).
2. Unzip it and double-click `IcoNVader.saver`.
3. Choose it in **System Settings → Screen Saver**. The **Options** button opens the settings panel.

It runs on macOS 11 or later, on Apple Silicon and Intel, and is signed and notarized by Apple.
When updating from a previous version, quit System Settings and run `killall legacyScreenSaver`,
otherwise macOS keeps the old one loaded.

**With [Homebrew](https://brew.sh):**

```bash
brew install --cask robertod91/tap/iconvader
```

Upgrade with `brew upgrade --cask iconvader`, remove with `brew uninstall --cask --zap iconvader`.

**Your own icons:** like the original, put a folder of `.icns` or `.png` files in
`~/Library/Application Support/IcoNVader/Icon Sets/` and it shows up in the **Icons** menu.

## Web version

https://robertodisanto.it/IcoNVader-rebuild/ — **P** opens the options, **F** goes full screen,
**Space** restarts the animation. You can also open `web/iconvader/index.html` locally.

## How it was rebuilt

- The original binary was disassembled and read class by class: each of the six animations
  (**Comets**, **Fireworks**, **Game Of Life**, **Hypnosis**, **DNA**, **Jumpers**) uses the same
  formulas, timing and even the small quirks of the original.
- It was rewritten twice, as a web page (JavaScript) and as a macOS screen saver (Swift). With the
  same random numbers the two produce exactly the same animation, frame by frame.
- The options panel is rebuilt from the original interface file: same tabs, controls and wording,
  in English and French like the original, plus Italian.

The details (in Italian) are in [`docs/iconvader/README.md`](docs/iconvader/README.md).

## For developers

```bash
cd macos && xcodegen generate && open IcoNVader.xcodeproj
```

```bash
macos/Tests/compare.sh
```

The first builds the screen saver in Xcode (needs `brew install xcodegen`); the second checks that
the Swift and JavaScript versions stay identical. The **Compila salvaschermo macOS** workflow
builds, tests, signs, notarizes and optionally publishes a release; signing is described in
[`docs/firma-macos.md`](docs/firma-macos.md).

## License

The code of this rebuild is released under the [MIT license](LICENSE). It does not cover the
original material by Daedale (the `IcoNVader.saver` bundle, its binary and icons, and their
conversions), which remains the property of its owners. IcoNVader 3.0 is © 2004-2006 Daedale; this
project is not affiliated with or endorsed by Daedale.
