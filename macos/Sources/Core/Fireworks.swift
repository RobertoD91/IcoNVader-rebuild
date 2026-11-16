// Fireworks — FireworksBehavior + FireworksActor.
// Razzi lanciati dal fondo che rallentano, si gonfiano in cima e scoppiano in 8 copie.

import Foundation

final class FireworksActor: IVActor {
    var velocity = IVPoint.zero
    var maxLife = 0
    var currentLife = 0

    /// Ordinamento invertito rispetto a IVActor: le più opache sopra, a parità le più vecchie sopra.
    override func compareDepth(_ other: IVActor) -> Int {
        if opacity == other.opacity {
            if identifier == other.identifier { return 0 }
            return identifier < other.identifier ? 1 : -1
        }
        return opacity > other.opacity ? 1 : -1
    }
}

/// N, NE, E, SE, S, SO, O, NO (diagonali non normalizzate).
private let sparkDirections: [(Double, Double)] = [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)]

public final class FireworksBehavior: IVBehavior {
    public override class var identifier: String { "Fireworks" }
    public override class var displayName: String { "Fireworks" }

    var fireworks: [FireworksActor] = []
    var sparks: [FireworksActor] = []
    var maxSpeed = 1

    public required init(bounds: IVRect, icons: [IVIcon], density: Int, lifeExpectancy: Int, scaleFactor: Double) {
        super.init(bounds: bounds, icons: icons, density: density, lifeExpectancy: lifeExpectancy, scaleFactor: scaleFactor)
        resetAnimation()
    }

    /// Velocità di lancio massima perché i razzi non escano dall'alto.
    public override func resetAnimation() {
        let H = bounds.height
        var k = 10
        var apex = 105.0
        while H > apex {
            k += 1
            let n = Double(2 * k)
            apex = n * (n - (n - 1) * 0.5) * 0.5
        }
        maxSpeed = max(1, k - 11)
        sparks = []
        fireworks = []
        actors = []
    }

    public override func animateOneFrame() {
        if sparks.count <= 399 {
            if ivRandom() % (101 - density) == 0 {
                let a = FireworksActor()
                resetActor(a)
                fireworks.append(a)
                actors.append(a)
            }
        }
        for a in fireworks { moveActor(a) }   // si itera su una copia (semantica di valore)
        for p in sparks { moveSpark(p) }
        sortActorsByDepth()
    }

    /// Lancio di un razzo.
    func resetActor(_ a: FireworksActor) {
        let sf = scaleFactor
        let s = 128 * sf
        a.image = randomIcon()
        a.angle = 0
        a.scale = IVPoint(x: sf, y: sf)
        a.opacity = 1
        let vy = Double(ivRandom() % maxSpeed + 10)
        let vx = Double(ivRandom() % 9 - 4)
        a.velocity = IVPoint(x: vx, y: vy)
        let span = max(1, bounds.width - 2 * s)
        a.location = IVPoint(x: ivRandomMod(span) + s, y: -s)
        a.maxLife = ivRandom() % 10
        a.currentLife = a.maxLife
    }

    func moveActor(_ a: FireworksActor) {
        let vel = a.velocity
        if !(vel.y > 0) {
            let cl = a.currentLife
            if cl == 0 {
                spawnSparks(at: a.location, image: a.image)
                fireworks.removeObject(a)
                actors.removeObject(a)
                return
            }
            let f = (Double(cl) / Double(a.maxLife)) * -2 + 3 // si gonfia fino a quasi 3×
            a.scale = IVPoint(x: f * scaleFactor, y: f * scaleFactor)
            a.currentLife = cl - 1
        }
        a.location = IVPoint(x: a.location.x + vel.x, y: a.location.y + vel.y)
        a.velocity = IVPoint(x: vel.x, y: vel.y - 0.5)
    }

    func spawnSparks(at loc: IVPoint, image: IVIcon?) {
        let m = max(1, (lifeExpectancy * 300) / 5000)
        let life = ivRandom() % m + 10 // stessa durata per le 8 scintille
        for (dx, dy) in sparkDirections {
            let p = FireworksActor()
            let speed = Double(ivRandom() % 10 + 1)
            p.image = image
            p.angle = 0
            p.scale = IVPoint(x: scaleFactor, y: scaleFactor)
            p.opacity = 1
            p.location = loc
            p.maxLife = life
            p.currentLife = life
            p.velocity = IVPoint(x: dx * speed, y: dy * speed)
            sparks.append(p)
            actors.append(p)
        }
    }

    func moveSpark(_ p: FireworksActor) {
        let cl = p.currentLife
        if cl == 0 {
            sparks.removeObject(p)
            actors.removeObject(p)
            return
        }
        let f = Double(cl) / Double(p.maxLife)
        p.opacity = f
        p.scale = IVPoint(x: f * scaleFactor, y: f * scaleFactor)
        p.currentLife = cl - 1
        p.location = IVPoint(x: p.location.x + p.velocity.x, y: p.location.y + p.velocity.y)
    }
}
