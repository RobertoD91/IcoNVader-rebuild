// Collaudo del bundle compilato (solo macOS).
//
// Uso: swiftc -o render macos/Tests/render.swift && ./render <IcoNVader.saver> <cartella_png>
//
// Carica il bundle come fa il sistema (NSBundle + NSPrincipalClass), imposta ogni comportamento
// nelle preferenze, crea la vista, anima alcuni secondi, disegna in una bitmap e salva un PNG.
// Fallisce se il bundle non si carica, se un fotogramma è vuoto o se il pannello opzioni non si crea.

import AppKit
import ScreenSaver

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("ERRORE: \(message)\n".data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 3 else { fail("uso: render <IcoNVader.saver> <cartella_png>") }
let outDir = URL(fileURLWithPath: args[2], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

_ = NSApplication.shared
NSApp.appearance = NSAppearance(named: .aqua) // screenshot del pannello nell'aspetto chiaro
guard let bundle = Bundle(url: URL(fileURLWithPath: args[1])) else { fail("bundle non trovato") }
guard bundle.load() else { fail("il bundle non si carica") }
guard let viewClass = bundle.principalClass as? ScreenSaverView.Type else { fail("NSPrincipalClass non è una ScreenSaverView") }
guard let moduleName = bundle.bundleIdentifier,
      let defaults = ScreenSaverDefaults(forModuleWithName: moduleName) else { fail("ScreenSaverDefaults non disponibile") }
print("Bundle caricato: \(moduleName), classe \(NSStringFromClass(viewClass))")

let frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
// Fireworks usa la densità massima: con quella predefinita (50) parte un razzo ogni ~51 fotogrammi
// e in un istante qualsiasi lo schermo può essere vuoto, facendo fallire il controllo.
let behaviors: [(id: String, frames: Int, icons: String, density: Int)] = [
    ("Comets", 150, "Christmas", 50), ("Fireworks", 150, "Daedale", 100), ("GameOfLife", 150, "Christmas", 50),
    ("Hypnosis", 150, "Daedale", 50), ("DNA", 150, "Christmas", 50), ("Jumpers", 150, "Daedale", 50),
]

for b in behaviors {
    defaults.set(false, forKey: "RandomBehavior")
    defaults.set(b.id, forKey: "Behavior")
    defaults.set(b.icons, forKey: "IconSetName")
    defaults.set(b.density, forKey: "Density")
    defaults.synchronize()

    guard let view = viewClass.init(frame: frame, isPreview: false) else { fail("init(frame:isPreview:) ha restituito nil") }
    view.startAnimation()
    for _ in 0..<b.frames { view.animateOneFrame() }
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fail("bitmap non creata") }
    view.cacheDisplay(in: view.bounds, to: rep)
    view.stopAnimation()

    // Conta i pixel non neri (sfondo predefinito nero) su una griglia di campionamento.
    var lit = 0, total = 0
    for y in stride(from: 0, to: rep.pixelsHigh, by: 4) {
        for x in stride(from: 0, to: rep.pixelsWide, by: 4) {
            total += 1
            if let c = rep.colorAt(x: x, y: y), c.redComponent + c.greenComponent + c.blueComponent > 0.05 { lit += 1 }
        }
    }
    let percent = Double(lit) * 100 / Double(total)
    guard let png = rep.representation(using: .png, properties: [:]) else { fail("PNG non creato") }
    try png.write(to: outDir.appendingPathComponent("\(b.id).png"))
    print(b.id.padding(toLength: 11, withPad: " ", startingAt: 0)
          + String(format: "%4d fotogrammi, %5.1f%% dello schermo disegnato", b.frames, percent))
    if lit == 0 { fail("\(b.id): fotogramma vuoto") }
}

// Pannello opzioni: ogni lingua (ICONVADER_LANG) e ogni scheda, salvati come PNG.
for language in ["en", "fr", "it"] {
    setenv("ICONVADER_LANG", language, 1)
    guard let preview = viewClass.init(frame: NSRect(x: 0, y: 0, width: 320, height: 200), isPreview: true) else { fail("anteprima non creata") }
    guard preview.hasConfigureSheet, let sheet = preview.configureSheet, let content = sheet.contentView else {
        fail("pannello opzioni non disponibile")
    }
    guard let tabView = content.subviews.compactMap({ $0 as? NSTabView }).first else { fail("schede non trovate") }
    let labels = tabView.tabViewItems.map(\.label)
    // La prima scheda si cattura per ultima: alla prima cattura i titoli delle schede non sono ancora disegnati.
    for index in Array(1..<tabView.numberOfTabViewItems) + [0] {
        tabView.selectTabViewItem(at: index)
        content.layoutSubtreeIfNeeded()
        guard let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { fail("bitmap del pannello non creata") }
        content.cacheDisplay(in: content.bounds, to: rep)
        // La vista non disegna lo sfondo della finestra: lo si aggiunge sotto, come lo vedrebbe l'utente.
        let shot = NSImage(size: content.bounds.size)
        shot.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        content.bounds.fill()
        rep.draw(in: content.bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        shot.unlockFocus()
        guard let tiff = shot.tiffRepresentation, let out = NSBitmapImageRep(data: tiff) else { fail("immagine del pannello non creata") }
        try out.representation(using: .png, properties: [:])?.write(to: outDir.appendingPathComponent("Opzioni-\(language)-\(index + 1).png"))
    }
    print("Pannello opzioni [\(language)]: \(Int(content.frame.width))×\(Int(content.frame.height)) pt, schede: \(labels.joined(separator: ", "))")
}
unsetenv("ICONVADER_LANG")

defaults.removeObject(forKey: "RandomBehavior")
defaults.removeObject(forKey: "Behavior")
defaults.removeObject(forKey: "IconSetName")
defaults.removeObject(forKey: "Density")
defaults.synchronize()
print("Collaudo completato.")
