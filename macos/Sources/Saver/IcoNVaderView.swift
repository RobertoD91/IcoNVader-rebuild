// IcoNVader (ricostruzione macOS) — vista del salvaschermo.
//
// Equivalente di IVScreenView + QuartzRenderer: sceglie il comportamento, carica le icone,
// anima a AnimationSpeed fotogrammi al secondo e disegna ogni attore centrato su location,
// ruotato di angle gradi, scalato e con opacità. La vista non è "flipped", quindi le
// coordinate sono già quelle di Cocoa usate dai comportamenti.

import AppKit
import os
import ScreenSaver

/// Log di diagnostica, visibile con:
/// log stream --predicate 'subsystem == "io.github.robertod91.IcoNVader"'
let ivLog = Logger(subsystem: "io.github.robertod91.IcoNVader", category: "saver")

@objc(IcoNVaderRestoredView)
final class IcoNVaderView: ScreenSaverView {
    private var preferences = PreferencesStore.load()
    private var behavior: IVBehavior?
    private var images: [CGImage] = []
    private var iconSetName: String?
    private var behaviorChangeTimer: Timer?
    private var configureSheetController: ConfigureSheetController?
    private var stopObserver: NSObjectProtocol?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / Double(preferences.animationSpeed)
        wantsLayer = true

        // Da macOS 14 il processo legacyScreenSaver non sempre chiama stopAnimation:
        // si ascolta la notifica di sistema per fermare l'animazione e liberare la CPU.
        stopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"), object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.isPreview else { return }
            self.stopAnimation()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        if let stopObserver { DistributedNotificationCenter.default().removeObserver(stopObserver) }
        behaviorChangeTimer?.invalidate()
    }

    // MARK: - Ciclo di vita (-[IVScreenView startAnimation])

    override func startAnimation() {
        ivLog.info("startAnimation (anteprima: \(self.isPreview, privacy: .public))")
        super.startAnimation()
        restartBehavior()
    }

    override func stopAnimation() {
        super.stopAnimation()
        behaviorChangeTimer?.invalidate()
        behaviorChangeTimer = nil
    }

    /// Sceglie il comportamento (casuale o fisso), carica le icone e crea tutto da capo.
    private func restartBehavior() {
        preferences = PreferencesStore.load()
        animationTimeInterval = 1.0 / Double(preferences.animationSpeed)

        behaviorChangeTimer?.invalidate()
        behaviorChangeTimer = nil
        let cls: IVBehavior.Type
        if preferences.randomBehavior {
            cls = allBehaviors[ivRandom() % allBehaviors.count]
            if preferences.randomBehaviorChangeInterval > 0 {
                behaviorChangeTimer = Timer.scheduledTimer(
                    withTimeInterval: TimeInterval(preferences.randomBehaviorChangeInterval), repeats: false
                ) { [weak self] _ in self?.restartBehavior() }
            }
        } else {
            cls = behaviorClass(forIdentifier: preferences.behavior)
        }

        if iconSetName != preferences.iconSet || images.isEmpty {
            images = IconLibrary.loadImages(forSet: preferences.iconSet)
            iconSetName = preferences.iconSet
        }
        let icons = images.enumerated().map { IVIcon(index: $0.offset, width: 128, height: 128) }
        behavior = icons.isEmpty ? nil : cls.init(
            bounds: ivBounds, icons: icons, density: preferences.density,
            lifeExpectancy: preferences.lifeExpectancy, scaleFactor: preferences.scaleFactor)
        needsDisplay = true
    }

    private var ivBounds: IVRect {
        IVRect(x: Double(bounds.origin.x), y: Double(bounds.origin.y),
               width: Double(bounds.width), height: Double(bounds.height))
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        behavior?.setBounds(ivBounds)
    }

    // MARK: - Animazione e disegno

    override func animateOneFrame() {
        behavior?.animateOneFrame()
        needsDisplay = true
    }

    override func draw(_ rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bg = preferences.backgroundColor
        ctx.setFillColor(CGColor(red: bg.red, green: bg.green, blue: bg.blue, alpha: 1))
        ctx.fill(bounds)

        guard let behavior else {
            drawMessage(L10n.t("message.invalidIconSet"))
            return
        }
        ctx.interpolationQuality = .high
        for actor in behavior.actors {
            guard let icon = actor.image, icon.index < images.count, actor.opacity > 0,
                  actor.scale.x != 0, actor.scale.y != 0 else { continue }
            let w = icon.width, h = icon.height
            ctx.saveGState()
            ctx.translateBy(x: actor.location.x, y: actor.location.y)
            ctx.rotate(by: actor.angle * .pi / 180)
            ctx.translateBy(x: -0.5 * w * actor.scale.x, y: -0.5 * h * actor.scale.y)
            ctx.scaleBy(x: actor.scale.x, y: actor.scale.y)
            ctx.setAlpha(min(1, max(0, actor.opacity)))
            ctx.draw(images[icon.index], in: CGRect(x: 0, y: 0, width: w, height: h))
            ctx.restoreGState()
        }
    }

    /// Messaggio mostrato quando il set di icone è vuoto (InvalidIconSetMessage dell'originale).
    private func drawMessage(_ text: String) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: isPreview ? 10 : 18),
            .paragraphStyle: style,
        ]
        let size = (text as NSString).boundingRect(
            with: NSSize(width: bounds.width - 40, height: bounds.height),
            options: .usesLineFragmentOrigin, attributes: attrs).size
        let r = NSRect(x: 20, y: (bounds.height - size.height) / 2, width: bounds.width - 40, height: size.height)
        (text as NSString).draw(with: r, options: .usesLineFragmentOrigin, attributes: attrs)
    }

    // MARK: - Opzioni

    override var hasConfigureSheet: Bool { true }

    /// Il sistema può leggere questa proprietà più volte prima di mostrare il pannello: si crea un
    /// solo controller per vista e si restituisce sempre la stessa finestra, aggiornata con le
    /// preferenze correnti. Creare ogni volta una finestra nuova liberava quella in apertura.
    override var configureSheet: NSWindow? {
        ivLog.info("configureSheet richiesto (anteprima: \(self.isPreview, privacy: .public))")
        if let controller = configureSheetController {
            controller.reload(with: PreferencesStore.load())
            return controller.window
        }
        let controller = ConfigureSheetController(preferences: PreferencesStore.load()) { [weak self] saved in
            guard let self else { return }
            if let saved {
                PreferencesStore.save(saved)
                self.restartBehavior()
            }
        }
        configureSheetController = controller
        ivLog.info("pannello opzioni creato: \(Int(controller.window.frame.width))x\(Int(controller.window.frame.height))")
        return controller.window
    }
}
