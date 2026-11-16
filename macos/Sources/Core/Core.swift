// IcoNVader (ricostruzione macOS) — nucleo indipendente da AppKit.
//
// Riproduce le classi di base del salvaschermo originale (IcoNVader 3.0, Daedale 2004-2006):
// IVActor, IVBehavior e le macro di ScreenSaver.framework. Usa solo Foundation, quindi si può
// compilare e collaudare anche su Linux (vedi macos/Tests). Coordinate Cocoa: origine in basso
// a sinistra, y verso l'alto, angoli in gradi in senso antiorario.

import Foundation

// MARK: - Geometria

public struct IVPoint: Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public static let zero = IVPoint(x: 0, y: 0)
}

public struct IVRect: Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    /// NSPointInRect: rettangolo semiaperto.
    public func contains(_ p: IVPoint) -> Bool {
        p.x >= x && p.x < x + width && p.y >= y && p.y < y + height
    }

    /// NSIntersectsRect: i bordi a contatto non contano.
    public func intersects(_ b: IVRect) -> Bool {
        if width <= 0 || height <= 0 || b.width <= 0 || b.height <= 0 { return false }
        return !(x + width <= b.x || b.x + b.width <= x || y + height <= b.y || b.y + b.height <= y)
    }
}

/// Riferimento a un'icona caricata dal livello grafico: indice nell'elenco e dimensioni (pt).
public struct IVIcon: Equatable {
    public let index: Int
    public let width: Double
    public let height: Double
    public init(index: Int, width: Double, height: Double) {
        self.index = index; self.width = width; self.height = height
    }
}

// MARK: - Numeri casuali

public enum IVRandom {
    /// Sorgente sostituibile (i test usano un generatore con seme). Restituisce un intero in [0, 2^31 - 1].
    public static var source: () -> Int = { Int.random(in: 0...2_147_483_647) }
}

/// random() della libc: intero in [0, 2^31 - 1].
@inline(__always) public func ivRandom() -> Int { IVRandom.source() }

/// fmod((double)random(), d) dell'originale, con divisore positivo.
@inline(__always) func ivRandomMod(_ d: Double) -> Double {
    Double(ivRandom()).truncatingRemainder(dividingBy: d)
}

let degreesToRadians = Double.pi / 180

// MARK: - IVActor

private var identifierSeed: UInt32 = 0 // sIdentifierSeed nel binario

open class IVActor {
    public let identifier: UInt32
    public var location = IVPoint.zero
    public var angle = 0.0                 // gradi
    public var scale = IVPoint.zero
    public var opacity = 0.0
    public var image: IVIcon?

    public init() {
        identifier = identifierSeed
        identifierSeed &+= 1
    }

    /// -[IVActor compareDepth:]: prima gli attori più opachi, a parità quelli con identificatore più alto.
    open func compareDepth(_ other: IVActor) -> Int {
        if opacity == other.opacity {
            if identifier == other.identifier { return 0 }
            return identifier < other.identifier ? 1 : -1
        }
        return other.opacity > opacity ? 1 : -1
    }
}

// MARK: - IVBehavior

open class IVBehavior {
    open class var identifier: String { "" }
    open class var displayName: String { "" }

    public internal(set) var bounds: IVRect
    public let icons: [IVIcon]
    public let density: Int          // 0...100
    public let lifeExpectancy: Int   // 100...5000 (fotogrammi)
    public let scaleFactor: Double   // 0.1...1.0
    public internal(set) var actors: [IVActor] = []

    public required init(bounds: IVRect, icons: [IVIcon], density: Int, lifeExpectancy: Int, scaleFactor: Double) {
        self.bounds = bounds
        self.icons = icons
        self.density = density
        self.lifeExpectancy = lifeExpectancy
        self.scaleFactor = scaleFactor
    }

    /// -[IVBehavior setBounds:] memorizza i nuovi limiti e riparte con resetAnimation.
    open func setBounds(_ bounds: IVRect) {
        self.bounds = bounds
        resetAnimation()
    }

    open func resetAnimation() {}
    open func animateOneFrame() {}

    /// Icona casuale dal set (random() % count, come nel binario).
    func randomIcon() -> IVIcon? {
        icons.isEmpty ? nil : icons[ivRandom() % icons.count]
    }

    /// sortUsingSelector:@selector(compareDepth:) dell'originale.
    func sortActorsByDepth() {
        actors.sort { $0.compareDepth($1) < 0 }
    }
}

/// Elenco dei comportamenti nell'ordine dell'originale.
public let allBehaviors: [IVBehavior.Type] = [
    CometsBehavior.self,
    FireworksBehavior.self,
    GameOfLifeBehavior.self,
    HypnosisBehavior.self,
    DNABehavior.self,
    JumpersBehavior.self,
]

public func behaviorClass(forIdentifier identifier: String) -> IVBehavior.Type {
    allBehaviors.first { $0.identifier == identifier } ?? allBehaviors[0]
}

extension Array where Element: AnyObject {
    /// removeObject: di NSMutableArray (rimuove per identità).
    mutating func removeObject(_ object: Element) {
        if let i = firstIndex(where: { $0 === object }) { remove(at: i) }
    }
}
