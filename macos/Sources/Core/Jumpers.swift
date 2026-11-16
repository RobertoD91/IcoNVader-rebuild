// Jumpers — JumpersBehavior + JumpersActor.
// Le icone compaiono, rimbalzano con gravità costante (a volte con una capriola), esplodono e rinascono.

import Foundation

final class JumpersActor: IVActor {
    enum Blow { case appearing, alive, exploding, dead }

    var velocity = IVPoint.zero
    var timeToLive = 0
    var rotationAction = 0           // 0 nessuna, 1 capriola in avanti, 2 all'indietro
    var rotationVelocityRange = 0.0
    var blowAction = Blow.appearing
    var blowFactor = 0.0
}

public final class JumpersBehavior: IVBehavior {
    public override class var identifier: String { "Jumpers" }
    public override class var displayName: String { "Jumpers" }

    public required init(bounds: IVRect, icons: [IVIcon], density: Int, lifeExpectancy: Int, scaleFactor: Double) {
        super.init(bounds: bounds, icons: icons, density: density, lifeExpectancy: lifeExpectancy, scaleFactor: scaleFactor)
        resetAnimation()
    }

    public override func resetAnimation() {
        let n = cometsActorCount(bounds, density)
        actors = []
        for _ in 0..<max(0, n) {
            let a = JumpersActor()
            resetActor(a)
            actors.append(a)
        }
    }

    /// Come nell'originale, non azzera opacità, angolo né la capriola in corso.
    func resetActor(_ a: JumpersActor) {
        let b = bounds
        let s0 = scaleFactor * 0.05
        a.image = randomIcon()
        let y = ivRandomMod(max(1, b.height - 70)) + 80
        let x = ivRandomMod(max(1, b.width - 40)) + 10
        a.location = IVPoint(x: x, y: y)
        a.scale = IVPoint(x: s0, y: s0)
        a.velocity = IVPoint(x: Double(ivRandom() % 9 - 4), y: 0)
        a.timeToLive = ivRandom() % max(1, lifeExpectancy)
        a.blowAction = .appearing
        a.blowFactor = 0.05
    }

    func moveActor(_ a: JumpersActor) {
        let B = bounds
        let sf = scaleFactor
        let v = a.velocity
        let x = a.location.x + v.x
        let y = a.location.y + v.y
        a.location = IVPoint(x: x, y: y)

        let iw = a.image?.width ?? 128
        let ih = a.image?.height ?? 128
        let halfW = 0.5 * (iw * sf)
        let halfH = (sf * ih) * 0.5

        // Pavimento e gravità
        var vx = v.x
        let vy: Double
        if halfH > y && v.y < 0 {
            vy = -v.y
            if ivRandom() & 3 == 0 { vx = -vx }
            a.rotationVelocityRange = abs(vy / 1.3)
            a.rotationAction = ivRandom() % 3
        } else {
            vy = v.y - 1
        }

        // Pareti laterali (formula del bordo destro come nell'originale)
        if x < B.x + halfW && vx < 0 {
            vx = -vx
        } else if x > (B.width - B.x) - halfW && vx > 0 {
            vx = -vx
        }
        a.velocity = IVPoint(x: vx, y: vy)

        // Macchina a stati: comparsa → vita → esplosione → morte
        var blow = a.blowFactor
        switch a.blowAction {
        case .appearing:
            blow += 0.05
            if blow > 1 { a.blowAction = .alive; blow = 0 }
        case .alive:
            blow += 1 / Double(a.timeToLive)
            if blow > 1 { a.blowAction = .exploding; blow = 0 }
        case .exploding:
            blow += 0.05
            if blow > 1 { a.blowAction = .dead }
        case .dead:
            break
        }
        a.blowFactor = blow

        // Capriola attorno al punto più alto del salto
        let R = a.rotationVelocityRange
        var angle = 0.0
        if !(R < abs(vy)) && R > 0 {
            if a.rotationAction == 1 { angle = (1 - vy / R) * 180 }
            else if a.rotationAction == 2 { angle = (vy / R + 1) * 180 }
        }
        a.angle = angle

        let s: Double
        switch a.blowAction {
        case .appearing: s = blow * sf
        case .exploding: s = (blow * 5 + 1) * sf
        default: s = sf
        }
        a.scale = IVPoint(x: s, y: s)

        switch a.blowAction {
        case .appearing: a.opacity = blow
        case .exploding: a.opacity = 1 - blow
        default: a.opacity = 1
        }
    }

    public override func animateOneFrame() {
        for case let a as JumpersActor in actors {
            moveActor(a)
            if a.blowAction == .dead { resetActor(a) }
        }
        sortActorsByDepth()
    }
}
