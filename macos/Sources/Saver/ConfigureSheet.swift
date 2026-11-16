// IcoNVader (ricostruzione macOS) — pannello opzioni (IVPreferencesController + IVPreferences.nib).
//
// Ricostruisce il pannello originale: finestra 456×357 con tre schede (Aspetto, Animazione,
// Avanzate) e i controlli alle coordinate lette dai nib English.lproj e French.lproj
// (decodificati dal formato typedstream). L'italiano usa la disposizione francese, che è pensata
// per testi più lunghi. Le coordinate sono quelle di AppKit: origine in basso a sinistra.

import AppKit

/// Rettangoli dei controlli per lingua (x, y, larghezza, altezza).
private struct PanelLayout {
    var frames: [String: NSRect]

    static let english = PanelLayout(frames: [
        // Scheda "Appearance"
        "iconsLabel": NSRect(x: 41, y: 225, width: 70, height: 17),
        "iconsPopUp": NSRect(x: 113, y: 219, width: 256, height: 26),
        "iconStrip": NSRect(x: 20, y: 117, width: 370, height: 86),
        "sizeLabel": NSRect(x: 39, y: 81, width: 86, height: 21),
        "sizeSlider": NSRect(x: 128, y: 74, width: 236, height: 25),
        "small": NSRect(x: 120, y: 59, width: 33, height: 14),
        "large": NSRect(x: 338, y: 59, width: 34, height: 14),
        "backgroundLabel": NSRect(x: 117, y: 20, width: 131, height: 20),
        "colorWell": NSRect(x: 253, y: 18, width: 38, height: 25),
        // Scheda "Animation"
        "invasionLabel": NSRect(x: 14, y: 224, width: 124, height: 21),
        "invasionSlider": NSRect(x: 141, y: 217, width: 236, height: 25),
        "scattered": NSRect(x: 101, y: 196, width: 109, height: 20),
        "rampant": NSRect(x: 338, y: 197, width: 58, height: 19),
        "lifeLabel": NSRect(x: 14, y: 167, width: 124, height: 21),
        "lifeSlider": NSRect(x: 141, y: 160, width: 236, height: 25),
        "bornDead": NSRect(x: 119, y: 145, width: 60, height: 14),
        "ancient": NSRect(x: 346, y: 139, width: 45, height: 20),
        "speedLabel": NSRect(x: 14, y: 110, width: 124, height: 21),
        "speedSlider": NSRect(x: 141, y: 103, width: 236, height: 25),
        "slow": NSRect(x: 133, y: 88, width: 33, height: 14),
        "fast": NSRect(x: 351, y: 88, width: 34, height: 14),
        "behaviorLabel": NSRect(x: 14, y: 49, width: 124, height: 21),
        "behaviorPopUp": NSRect(x: 140, y: 46, width: 192, height: 26),
        "randomLabel": NSRect(x: 34, y: 22, width: 161, height: 17),
        "randomPopUp": NSRect(x: 197, y: 16, width: 135, height: 26),
        // Scheda "Advanced"
        "rendererLabel": NSRect(x: 36, y: 222, width: 149, height: 20),
        "rendererPopUp": NSRect(x: 187, y: 219, width: 188, height: 26),
        "rendererLogo": NSRect(x: 138, y: 54, width: 134, height: 134),
        "credit": NSRect(x: 63, y: 7, width: 285, height: 13),
        // Finestra
        "cancel": NSRect(x: 274, y: 12, width: 84, height: 32),
        "ok": NSRect(x: 358, y: 12, width: 84, height: 32),
    ])

    static let french: PanelLayout = {
        var l = english
        l.frames.merge([
            "sizeLabel": NSRect(x: 20, y: 85, width: 121, height: 17),
            "sizeSlider": NSRect(x: 144, y: 74, width: 236, height: 25),
            "small": NSRect(x: 136, y: 59, width: 34, height: 14),
            "large": NSRect(x: 348, y: 59, width: 43, height: 14),
            "backgroundLabel": NSRect(x: 98, y: 20, width: 169, height: 21),
            "colorWell": NSRect(x: 272, y: 18, width: 38, height: 25),
            "scattered": NSRect(x: 114, y: 202, width: 72, height: 14),
            "rampant": NSRect(x: 338, y: 202, width: 61, height: 14),
            "bornDead": NSRect(x: 125, y: 145, width: 49, height: 14),
            "ancient": NSRect(x: 348, y: 145, width: 41, height: 14),
            "slow": NSRect(x: 133, y: 88, width: 34, height: 14),
            "fast": NSRect(x: 346, y: 88, width: 41, height: 14),
            "behaviorLabel": NSRect(x: 72, y: 52, width: 178, height: 17),
            "behaviorPopUp": NSRect(x: 252, y: 46, width: 141, height: 26),
            "randomLabel": NSRect(x: 18, y: 22, width: 232, height: 17),
            "randomPopUp": NSRect(x: 252, y: 16, width: 141, height: 26),
            "rendererLabel": NSRect(x: 84, y: 222, width: 102, height: 20),
            "rendererPopUp": NSRect(x: 188, y: 219, width: 139, height: 26),
            "credit": NSRect(x: 58, y: 7, width: 294, height: 13),
            "cancel": NSRect(x: 268, y: 12, width: 90, height: 32),
        ]) { $1 }
        return l
    }()

    static func forLanguage(_ language: String) -> PanelLayout {
        language == "en" ? english : french
    }

    subscript(_ key: String) -> NSRect { frames[key] ?? .zero }
}

final class ConfigureSheetController: NSObject {
    let window: NSWindow
    private let completion: (IVPreferences?) -> Void
    private var preferences: IVPreferences
    private let layout = PanelLayout.forLanguage(L10n.language)

    private let tabView = NSTabView()
    private let behaviorPopUp = NSPopUpButton()
    private let intervalPopUp = NSPopUpButton()
    private let iconSetPopUp = NSPopUpButton()
    private let rendererPopUp = NSPopUpButton()
    private let lifeSlider = NSSlider()
    private let densitySlider = NSSlider()
    private let speedSlider = NSSlider()
    private let scaleSlider = NSSlider()
    private let colorWell = NSColorWell()
    private let iconStrip = NSScrollView()

    private static let randomTag = -1
    private static let repositoryURL = URL(string: "https://github.com/RobertoD91/IcoNVader-rebuild")!

    init(preferences: IVPreferences, completion: @escaping (IVPreferences?) -> Void) {
        self.preferences = preferences
        self.completion = completion
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 456, height: 357),
                          styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        window.title = "IcoNVader"
        // La finestra viene riusata a ogni apertura: non deve essere liberata alla chiusura.
        window.isReleasedWhenClosed = false
        buildInterface()
        fill(with: preferences)
    }

    // MARK: - Costruzione dell'interfaccia

    private func buildInterface() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 456, height: 357))

        tabView.frame = NSRect(x: 13, y: 40, width: 430, height: 311)
        tabView.addTabViewItem(item("tab.appearance", appearanceTab()))
        tabView.addTabViewItem(item("tab.animation", animationTab()))
        tabView.addTabViewItem(item("tab.advanced", advancedTab()))
        content.addSubview(tabView)

        let cancel = NSButton(title: L10n.t("button.cancel"), target: self, action: #selector(cancel))
        cancel.frame = layout["cancel"]
        cancel.keyEquivalent = "\u{1b}"
        let ok = NSButton(title: L10n.t("button.ok"), target: self, action: #selector(save))
        ok.frame = layout["ok"]
        ok.keyEquivalent = "\r"
        content.addSubview(cancel)
        content.addSubview(ok)

        // Le schede dei macOS recenti hanno margini diversi da quelli di Mac OS X 10.4: si allarga
        // la vista a schede (e la finestra) quanto basta perché l'area interna resti 410×265.
        let inner = tabView.contentRect
        let dw = max(0, 410 - inner.width), dh = max(0, 265 - inner.height)
        tabView.setFrameSize(NSSize(width: tabView.frame.width + dw, height: tabView.frame.height + dh))
        content.setFrameSize(NSSize(width: 456 + dw, height: 357 + dh))
        window.setContentSize(content.frame.size)
        window.contentView = content
    }

    private func item(_ titleKey: String, _ view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: titleKey)
        item.label = L10n.t(titleKey)
        item.view = view
        return item
    }

    private func tabContent() -> NSView { NSView(frame: NSRect(x: 0, y: 0, width: 410, height: 265)) }

    /// Scheda "Aspetto": set di icone con anteprima, dimensione, colore di sfondo.
    private func appearanceTab() -> NSView {
        let v = tabContent()
        add(label("label.icons", "iconsLabel"), to: v)
        let sets = IconLibrary.availableSets()
        iconSetPopUp.addItems(withTitles: sets.isEmpty ? [L10n.t("message.noSet")] : sets)
        iconSetPopUp.isEnabled = !sets.isEmpty
        iconSetPopUp.target = self
        iconSetPopUp.action = #selector(iconSetChanged)
        add(iconSetPopUp, "iconsPopUp", to: v)

        iconStrip.hasHorizontalScroller = true
        iconStrip.hasVerticalScroller = false
        iconStrip.borderType = .bezelBorder
        iconStrip.drawsBackground = true
        iconStrip.backgroundColor = .controlBackgroundColor
        add(iconStrip, "iconStrip", to: v)

        add(label("label.iconSize", "sizeLabel"), to: v)
        configure(scaleSlider, IVPreferences.scaleFactorRange.lowerBound, IVPreferences.scaleFactorRange.upperBound)
        add(scaleSlider, "sizeSlider", to: v)
        add(endLabel("end.small", "small", .left), to: v)
        add(endLabel("end.large", "large", .right), to: v)

        add(label("label.background", "backgroundLabel"), to: v)
        add(colorWell, "colorWell", to: v)
        return v
    }

    /// Scheda "Animazione": invasione, vita, velocità, comportamento e cambio casuale.
    private func animationTab() -> NSView {
        let v = tabContent()
        add(label("label.invasion", "invasionLabel"), to: v)
        configure(densitySlider, Double(IVPreferences.densityRange.lowerBound), Double(IVPreferences.densityRange.upperBound))
        add(densitySlider, "invasionSlider", to: v)
        add(endLabel("end.scattered", "scattered", .left), to: v)
        add(endLabel("end.rampant", "rampant", .right), to: v)

        add(label("label.life", "lifeLabel"), to: v)
        configure(lifeSlider, Double(IVPreferences.lifeExpectancyRange.lowerBound), Double(IVPreferences.lifeExpectancyRange.upperBound))
        add(lifeSlider, "lifeSlider", to: v)
        add(endLabel("end.bornDead", "bornDead", .left), to: v)
        add(endLabel("end.ancient", "ancient", .right), to: v)

        add(label("label.speed", "speedLabel"), to: v)
        configure(speedSlider, Double(IVPreferences.animationSpeedRange.lowerBound), Double(IVPreferences.animationSpeedRange.upperBound))
        add(speedSlider, "speedSlider", to: v)
        add(endLabel("end.slow", "slow", .left), to: v)
        add(endLabel("end.fast", "fast", .right), to: v)

        add(label("label.behavior", "behaviorLabel"), to: v)
        behaviorPopUp.addItem(withTitle: L10n.behaviorName("Random"))
        behaviorPopUp.lastItem?.tag = Self.randomTag
        let separator = NSMenuItem.separator()
        separator.tag = -2 // diverso dagli indici dei comportamenti
        behaviorPopUp.menu?.addItem(separator)
        for (i, cls) in allBehaviors.enumerated() {
            behaviorPopUp.addItem(withTitle: L10n.behaviorName(cls.identifier))
            behaviorPopUp.lastItem?.tag = i
        }
        behaviorPopUp.target = self
        behaviorPopUp.action = #selector(behaviorChanged)
        add(behaviorPopUp, "behaviorPopUp", to: v)

        add(label("label.randomEvery", "randomLabel"), to: v)
        for (seconds, _) in IVPreferences.changeIntervals {
            intervalPopUp.addItem(withTitle: L10n.t("interval.\(seconds)"))
            intervalPopUp.lastItem?.tag = seconds
        }
        add(intervalPopUp, "randomPopUp", to: v)
        return v
    }

    /// Scheda "Avanzate": motore di disegno con il suo logo e crediti.
    private func advancedTab() -> NSView {
        let v = tabContent()
        add(label("label.renderer", "rendererLabel"), to: v)
        // L'originale offriva Quartz e OpenGL, che davano lo stesso risultato: qui si disegna con
        // Core Graphics, cioè Quartz 2D.
        rendererPopUp.addItem(withTitle: "Quartz")
        add(rendererPopUp, "rendererPopUp", to: v)

        let logo = NSImageView()
        logo.imageScaling = .scaleProportionallyUpOrDown
        if let url = Bundle(for: IcoNVaderView.self).url(forResource: "Quartz", withExtension: "tiff") {
            logo.image = NSImage(contentsOf: url)
        }
        add(logo, "rendererLogo", to: v)

        let credit = NSTextField(labelWithString: L10n.t("credit.original"))
        credit.font = .systemFont(ofSize: 10)
        credit.alignment = .center
        add(credit, "credit", to: v)

        // Aggiunta della ricostruzione (non presente nell'originale): nota e link al repository.
        let note = NSTextField(labelWithString: L10n.t("credit.rebuild"))
        note.font = .systemFont(ofSize: 10)
        note.alignment = .center
        note.frame = NSRect(x: 5, y: 38, width: 400, height: 13)
        v.addSubview(note)
        let link = NSButton(title: "github.com/RobertoD91/IcoNVader-rebuild", target: self, action: #selector(openRepository))
        link.isBordered = false
        link.font = .systemFont(ofSize: 10)
        link.contentTintColor = .linkColor
        link.frame = NSRect(x: 5, y: 22, width: 400, height: 15)
        v.addSubview(link)
        return v
    }

    private func add(_ view: NSView, _ key: String, to parent: NSView) {
        view.frame = layout[key]
        parent.addSubview(view)
    }

    private func add(_ field: NSTextField, to parent: NSView) {
        parent.addSubview(field)
    }

    /// Etichetta a sinistra di un controllo, allineata a destra come nel nib.
    private func label(_ key: String, _ frameKey: String) -> NSTextField {
        let f = NSTextField(labelWithString: L10n.t(key))
        f.alignment = .right
        var r = layout[frameKey]
        // Se il testo tradotto è più lungo del campo originale, lo si allarga verso sinistra
        // tenendo fermo il bordo destro, che è allineato al controllo.
        let needed = ceil(f.intrinsicContentSize.width)
        if needed > r.width {
            let grow = min(needed - r.width, r.minX)
            r.origin.x -= grow
            r.size.width += grow
        }
        f.frame = r
        return f
    }

    /// Etichetta piccola agli estremi di uno slider.
    private func endLabel(_ key: String, _ frameKey: String, _ alignment: NSTextAlignment) -> NSTextField {
        let f = NSTextField(labelWithString: L10n.t(key))
        f.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        f.alignment = alignment
        var r = layout[frameKey]
        // Il testo tradotto può essere più lungo: si allarga verso l'esterno dello slider.
        let needed = ceil(f.intrinsicContentSize.width)
        if needed > r.width {
            if alignment == .right { r.size.width = needed } else { r.origin.x -= needed - r.width; r.size.width = needed }
        }
        f.frame = r
        return f
    }

    private func configure(_ slider: NSSlider, _ min: Double, _ max: Double) {
        slider.minValue = min
        slider.maxValue = max
    }

    // MARK: - Anteprima delle icone (oIconTable: una riga, una colonna per icona)

    private func showIcons(forSet name: String) {
        let images = IconLibrary.iconURLs(forSet: name).compactMap { NSImage(contentsOf: $0) }
        let height = iconStrip.contentSize.height
        let side = min(64, height - 4)
        let slot = side + 6
        let doc = NSView(frame: NSRect(x: 0, y: 0, width: max(iconStrip.contentSize.width, slot * CGFloat(images.count) + 6), height: height))
        for (i, image) in images.enumerated() {
            let iv = NSImageView(frame: NSRect(x: 6 + CGFloat(i) * slot, y: (height - side) / 2, width: side, height: side))
            iv.image = image
            iv.imageScaling = .scaleProportionallyUpOrDown
            doc.addSubview(iv)
        }
        iconStrip.documentView = doc
    }

    // MARK: - Valori

    private func fill(with p: IVPreferences) {
        if p.randomBehavior {
            behaviorPopUp.selectItem(withTag: Self.randomTag)
        } else if let i = allBehaviors.firstIndex(where: { $0.identifier == p.behavior }) {
            behaviorPopUp.selectItem(withTag: i)
        }
        if !intervalPopUp.selectItem(withTag: p.randomBehaviorChangeInterval) {
            intervalPopUp.selectItem(withTag: 300)
        }
        if iconSetPopUp.isEnabled {
            iconSetPopUp.selectItem(withTitle: p.iconSet)
            if iconSetPopUp.indexOfSelectedItem < 0 { iconSetPopUp.selectItem(at: 0) }
            showIcons(forSet: iconSetPopUp.titleOfSelectedItem ?? p.iconSet)
        }
        lifeSlider.integerValue = p.lifeExpectancy
        densitySlider.integerValue = p.density
        speedSlider.integerValue = p.animationSpeed
        scaleSlider.doubleValue = p.scaleFactor
        colorWell.color = NSColor(srgbRed: p.backgroundColor.red, green: p.backgroundColor.green,
                                  blue: p.backgroundColor.blue, alpha: 1)
        behaviorChanged()
    }

    private func read() -> IVPreferences {
        var p = preferences
        let tag = behaviorPopUp.selectedTag()
        p.randomBehavior = tag == Self.randomTag
        if tag >= 0 && tag < allBehaviors.count { p.behavior = allBehaviors[tag].identifier }
        p.randomBehaviorChangeInterval = intervalPopUp.selectedTag()
        if iconSetPopUp.isEnabled, let title = iconSetPopUp.titleOfSelectedItem { p.iconSet = title }
        p.lifeExpectancy = lifeSlider.integerValue
        p.density = densitySlider.integerValue
        p.animationSpeed = speedSlider.integerValue
        p.scaleFactor = (scaleSlider.doubleValue * 100).rounded() / 100
        if let c = colorWell.color.usingColorSpace(.sRGB) {
            p.backgroundColor = IVColor(red: Double(c.redComponent), green: Double(c.greenComponent),
                                        blue: Double(c.blueComponent))
        }
        return p.clamped()
    }

    // MARK: - Azioni

    @objc private func behaviorChanged() {
        intervalPopUp.isEnabled = behaviorPopUp.selectedTag() == Self.randomTag
    }

    @objc private func iconSetChanged() {
        if let title = iconSetPopUp.titleOfSelectedItem { showIcons(forSet: title) }
    }

    @objc private func openRepository() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    @objc private func cancel() {
        close(with: nil)
    }

    @objc private func save() {
        close(with: read())
    }

    /// Riapertura del pannello: ricarica i valori salvati.
    func reload(with prefs: IVPreferences) {
        preferences = prefs
        fill(with: prefs)
    }

    private func close(with result: IVPreferences?) {
        NSColorPanel.shared.close()
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.orderOut(nil)
        }
        ivLog.info("pannello opzioni chiuso (\(result == nil ? "annulla" : "OK", privacy: .public))")
        completion(result)
    }
}
