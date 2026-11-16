// IcoNVader (ricostruzione macOS) — pannello opzioni (equivalente di IVPreferencesController).
// Costruito da codice, senza nib, con le stesse voci del pannello originale.

import AppKit

final class ConfigureSheetController: NSObject {
    let window: NSWindow
    private let completion: (IVPreferences?) -> Void
    private var preferences: IVPreferences

    private let behaviorPopUp = NSPopUpButton()
    private let intervalPopUp = NSPopUpButton()
    private let iconSetPopUp = NSPopUpButton()
    private let lifeSlider = NSSlider()
    private let densitySlider = NSSlider()
    private let speedSlider = NSSlider()
    private let scaleSlider = NSSlider()
    private let colorWell = NSColorWell()
    private var valueLabels: [NSSlider: NSTextField] = [:]

    private static let randomTag = -1

    init(preferences: IVPreferences, completion: @escaping (IVPreferences?) -> Void) {
        self.preferences = preferences
        self.completion = completion
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
                          styleMask: [.titled], backing: .buffered, defer: true)
        super.init()
        window.title = "IcoNVader"
        buildInterface()
        fill(with: preferences)
    }

    // MARK: - Costruzione dell'interfaccia

    private func buildInterface() {
        for (i, cls) in allBehaviors.enumerated() {
            behaviorPopUp.addItem(withTitle: cls.displayName)
            behaviorPopUp.lastItem?.tag = i
        }
        let separator = NSMenuItem.separator()
        separator.tag = -2 // diverso dagli indici dei comportamenti
        behaviorPopUp.menu?.insertItem(separator, at: 0)
        behaviorPopUp.insertItem(withTitle: "Casuale", at: 0)
        behaviorPopUp.item(at: 0)?.tag = Self.randomTag
        behaviorPopUp.target = self
        behaviorPopUp.action = #selector(behaviorChanged)

        for (seconds, label) in IVPreferences.changeIntervals {
            intervalPopUp.addItem(withTitle: label)
            intervalPopUp.lastItem?.tag = seconds
        }

        let sets = IconLibrary.availableSets()
        iconSetPopUp.addItems(withTitles: sets.isEmpty ? ["Nessun set disponibile"] : sets)
        iconSetPopUp.isEnabled = !sets.isEmpty

        configure(lifeSlider, IVPreferences.lifeExpectancyRange.lowerBound, IVPreferences.lifeExpectancyRange.upperBound)
        configure(densitySlider, IVPreferences.densityRange.lowerBound, IVPreferences.densityRange.upperBound)
        configure(speedSlider, IVPreferences.animationSpeedRange.lowerBound, IVPreferences.animationSpeedRange.upperBound)
        scaleSlider.minValue = IVPreferences.scaleFactorRange.lowerBound
        scaleSlider.maxValue = IVPreferences.scaleFactorRange.upperBound
        scaleSlider.target = self
        scaleSlider.action = #selector(sliderChanged(_:))

        let grid = NSGridView(views: [
            [label("Comportamento:"), behaviorPopUp],
            [label("Cambia ogni:"), intervalPopUp],
            [label("Aspettativa di vita:"), sliderRow(lifeSlider, "Nate morte", "Antiche")],
            [label("Livello d'invasione:"), sliderRow(densitySlider, "Resti sparsi", "Dilagante")],
            [label("Velocità:"), sliderRow(speedSlider, "Lenta", "Veloce")],
            [label("Icone:"), iconSetPopUp],
            [label("Dimensione icone:"), sliderRow(scaleSlider, "Piccole", "Grandi")],
            [label("Colore di sfondo:"), colorWell],
        ])
        grid.rowSpacing = 14
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        colorWell.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let defaultsButton = NSButton(title: "Predefiniti", target: self, action: #selector(restoreDefaults))
        let cancelButton = NSButton(title: "Annulla", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let okButton = NSButton(title: "OK", target: self, action: #selector(save))
        okButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [defaultsButton, spacer(), cancelButton, okButton])
        buttons.distribution = .fill

        let credit = NSTextField(labelWithString:
            "Ricostruzione di IcoNVader 3.0 (© 2004-2006 Daedale) a scopo didattico.")
        credit.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        credit.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [grid, credit, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func configure(_ slider: NSSlider, _ min: Int, _ max: Int) {
        slider.minValue = Double(min)
        slider.maxValue = Double(max)
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
    }

    /// Slider con valore corrente e le etichette agli estremi, come nel pannello originale.
    private func sliderRow(_ slider: NSSlider, _ left: String, _ right: String) -> NSView {
        slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        let value = NSTextField(labelWithString: "")
        value.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.alignment = .right
        value.widthAnchor.constraint(equalToConstant: 70).isActive = true
        valueLabels[slider] = value
        let ends = NSStackView(views: [small(left), spacer(), small(right)])
        let top = NSStackView(views: [slider, value])
        let column = NSStackView(views: [top, ends])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 2
        ends.widthAnchor.constraint(equalTo: slider.widthAnchor).isActive = true
        return column
    }

    /// Riempitivo elastico per le righe orizzontali.
    private func spacer() -> NSView {
        let v = NSView()
        v.setContentHuggingPriority(.init(1), for: .horizontal)
        v.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        return v
    }

    private func small(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        f.textColor = .secondaryLabelColor
        return f
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
        }
        lifeSlider.integerValue = p.lifeExpectancy
        densitySlider.integerValue = p.density
        speedSlider.integerValue = p.animationSpeed
        scaleSlider.doubleValue = p.scaleFactor
        colorWell.color = NSColor(srgbRed: p.backgroundColor.red, green: p.backgroundColor.green,
                                  blue: p.backgroundColor.blue, alpha: 1)
        for slider in [lifeSlider, densitySlider, speedSlider, scaleSlider] { sliderChanged(slider) }
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

    @objc private func sliderChanged(_ sender: NSSlider) {
        let text: String
        switch sender {
        case lifeSlider: text = "\(sender.integerValue) fot."
        case speedSlider: text = "\(sender.integerValue) fps"
        case scaleSlider: text = "\(Int((sender.doubleValue * 100).rounded()))%"
        default: text = "\(sender.integerValue)"
        }
        valueLabels[sender]?.stringValue = text
    }

    @objc private func behaviorChanged() {
        intervalPopUp.isEnabled = behaviorPopUp.selectedTag() == Self.randomTag
    }

    @objc private func restoreDefaults() {
        fill(with: IVPreferences())
    }

    @objc private func cancel() {
        close(with: nil)
    }

    @objc private func save() {
        close(with: read())
    }

    private func close(with result: IVPreferences?) {
        NSColorPanel.shared.close()
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
        completion(result)
    }
}
