// Preferenze di IcoNVader (IVPreferences + DefaultPreferences.plist), senza dipendenze da AppKit.

import Foundation

public struct IVColor: Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public init(red: Double, green: Double, blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
    public static let black = IVColor(red: 0, green: 0, blue: 0)
}

public struct IVPreferences: Equatable {
    public var animationSpeed = 30                 // fotogrammi al secondo (10...60)
    public var density = 50                        // "Livello d'invasione" (0...100)
    public var lifeExpectancy = 1200               // "Aspettativa di vita" (100...5000)
    public var scaleFactor = 0.6                   // "Dimensione icone" (0.1...1.0)
    public var randomBehavior = true
    public var randomBehaviorChangeInterval = 300  // secondi; 0 = mai
    public var behavior = "Comets"                 // senza preferenza: il primo della lista
    public var iconSet = "Christmas"
    public var backgroundColor = IVColor.black     // ShadingColor

    public init() {}

    public static let animationSpeedRange = 10...60
    public static let densityRange = 0...100
    public static let lifeExpectancyRange = 100...5000
    public static let scaleFactorRange = 0.1...1.0

    /// Voci del menu "Cambia comportamento ogni" (tag in secondi, come nel nib originale).
    public static let changeIntervals: [(seconds: Int, label: String)] = [
        (10, "10 secondi"), (60, "1 minuto"), (300, "5 minuti"), (600, "10 minuti"),
        (1800, "30 minuti"), (3600, "1 ora"), (0, "Mai"),
    ]

    /// Riporta i valori negli intervalli ammessi (come i controlli di IVPreferences).
    public func clamped() -> IVPreferences {
        var p = self
        p.animationSpeed = min(max(animationSpeed, 10), 60)
        p.density = min(max(density, 0), 100)
        p.lifeExpectancy = min(max(lifeExpectancy, 100), 5000)
        p.scaleFactor = scaleFactor.isFinite ? min(max(scaleFactor, 0.1), 1.0) : 0.6
        p.randomBehaviorChangeInterval = max(0, randomBehaviorChangeInterval)
        return p
    }

    // Chiavi identiche a quelle dell'originale.
    public enum Key {
        public static let animationSpeed = "AnimationSpeed"
        public static let density = "Density"
        public static let lifeExpectancy = "LifeExpectancy"
        public static let scaleFactor = "ScaleFactor"
        public static let randomBehavior = "RandomBehavior"
        public static let randomBehaviorChangeInterval = "RandomBehaviorChangeInterval"
        public static let behavior = "Behavior"
        public static let iconSet = "IconSetName"
        public static let backgroundColor = "BackgroundColor"
    }

    /// Lettura da un dizionario di valori (UserDefaults/ScreenSaverDefaults).
    public init(dictionary d: [String: Any]) {
        self.init()
        if let v = d[Key.animationSpeed] as? Int { animationSpeed = v }
        if let v = d[Key.density] as? Int { density = v }
        if let v = d[Key.lifeExpectancy] as? Int { lifeExpectancy = v }
        if let v = d[Key.scaleFactor] as? Double { scaleFactor = v }
        if let v = d[Key.randomBehavior] as? Bool { randomBehavior = v }
        if let v = d[Key.randomBehaviorChangeInterval] as? Int { randomBehaviorChangeInterval = v }
        if let v = d[Key.behavior] as? String { behavior = v }
        if let v = d[Key.iconSet] as? String { iconSet = v }
        if let v = d[Key.backgroundColor] as? [Double], v.count == 3 {
            backgroundColor = IVColor(red: v[0], green: v[1], blue: v[2])
        }
        self = clamped()
    }

    public var dictionary: [String: Any] {
        [
            Key.animationSpeed: animationSpeed,
            Key.density: density,
            Key.lifeExpectancy: lifeExpectancy,
            Key.scaleFactor: scaleFactor,
            Key.randomBehavior: randomBehavior,
            Key.randomBehaviorChangeInterval: randomBehaviorChangeInterval,
            Key.behavior: behavior,
            Key.iconSet: iconSet,
            Key.backgroundColor: [backgroundColor.red, backgroundColor.green, backgroundColor.blue],
        ]
    }
}
