// Comets — CometsBehavior + CometsActor.
// Le icone entrano dai bordi in linea retta, rimpiccioliscono e svaniscono, poi rinascono.

import Foundation

final class CometsActor: IVActor {
    var velocity = IVPoint.zero
    var timeToLive = 0
    var blowFactor = 0.0
    var hasLived = false
}

/// Numero di attori di Comets e Jumpers: larghezza/128 × (densità+3)/10.
func cometsActorCount(_ bounds: IVRect, _ density: Int) -> Int {
    Int(bounds.width * 0.0078125 * ((Double(density) + 3) / 10))
}

public final class CometsBehavior: IVBehavior {
    public override class var identifier: String { "Comets" }
    public override class var displayName: String { "Comets" }

    public required init(bounds: IVRect, icons: [IVIcon], density: Int, lifeExpectancy: Int, scaleFactor: Double) {
        super.init(bounds: bounds, icons: icons, density: density, lifeExpectancy: lifeExpectancy, scaleFactor: scaleFactor)
        resetAnimation()
    }

    public override func resetAnimation() {
        let n = cometsActorCount(bounds, density)
        actors = []
        for _ in 0..<max(0, n) {
            let a = CometsActor()
            resetActor(a)
            actors.append(a)
        }
    }

    func resetActor(_ a: CometsActor) {
        let sf = scaleFactor
        let W = bounds.width
        let H = bounds.height
        var x: Double, y: Double, dir: IVPoint
        switch ivRandom() % 4 {
        case 0: // bordo sinistro, verso destra
            x = -128 * sf
            y = ivRandomMod(H)
            dir = IVPoint(x: 1, y: Double(ivRandom() % 2)) // 0 o 1: mai verso il basso
        case 1: // bordo superiore, verso il basso
            x = ivRandomMod(W)
            y = H + sf * 128
            dir = IVPoint(x: Double(ivRandom() % 2), y: -1)
        case 2: // bordo destro, verso sinistra
            x = W + sf * 128
            y = ivRandomMod(H)
            dir = IVPoint(x: -1, y: Double(ivRandom() % 2))
        default: // bordo inferiore, verso l'alto
            x = ivRandomMod(W)
            y = -128 * sf
            dir = IVPoint(x: Double(ivRandom() % 2), y: 1)
        }
        a.image = randomIcon()
        a.angle = 0
        a.scale = IVPoint(x: sf, y: sf)
        a.blowFactor = 1
        a.opacity = 1
        let r1 = ivRandom()
        let r2 = ivRandom()
        a.velocity = IVPoint(x: Double(r2 % 10 + 3) * dir.x, y: Double(r1 % 10 + 3) * dir.y)
        a.timeToLive = (ivRandom() % max(1, lifeExpectancy)) / 5
        a.location = IVPoint(x: x, y: y)
        a.hasLived = false
    }

    func moveActor(_ a: CometsActor) {
        let blow = a.blowFactor + (-1 / Double(a.timeToLive))
        a.blowFactor = blow
        a.location = IVPoint(x: a.location.x + a.velocity.x, y: a.location.y + a.velocity.y)
        a.scale = IVPoint(x: blow * scaleFactor, y: blow * scaleFactor)
        a.opacity = blow
        if bounds.contains(a.location) { a.hasLived = true }
    }

    public override func animateOneFrame() {
        for case let a as CometsActor in actors {
            moveActor(a)
            if a.blowFactor <= 0.05 {
                resetActor(a)
            } else if a.hasLived && !bounds.contains(a.location) {
                resetActor(a)
            }
        }
        sortActorsByDepth()
    }
}
