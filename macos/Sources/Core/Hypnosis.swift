// Hypnosis — HypnosisBehavior + HypnosisActor.
// Anelli concentrici di icone che ruotano in direzioni alterne attorno al centro dello schermo.

import Foundation

final class HypnosisActor: IVActor {
    var velocity = 0.0      // gradi per fotogramma
    var waveAction = 0      // 0 = antiorario, 1 = orario
    var waveAngle = 0.0     // posizione angolare sull'anello (gradi)
    var waveRadius = 0.0    // raggio dell'anello (pt)
}

public final class HypnosisBehavior: IVBehavior {
    public override class var identifier: String { "Hypnosis" }
    public override class var displayName: String { "Hypnosis" }

    public required init(bounds: IVRect, icons: [IVIcon], density: Int, lifeExpectancy: Int, scaleFactor: Double) {
        super.init(bounds: bounds, icons: icons, density: density, lifeExpectancy: lifeExpectancy, scaleFactor: scaleFactor)
        resetAnimation()
    }

    public override func resetAnimation() {
        let maxDim = max(bounds.width, bounds.height)
        var spacing = maxDim / 14
        let ringCount: Int
        let iconScale: Double
        if spacing > 128 {
            ringCount = Int(maxDim * (1 / 256) + 1)
            spacing = 128
            iconScale = 1
        } else {
            iconScale = spacing * (1 / 128)
            ringCount = 7
        }
        actors = []
        guard spacing > 0 else { return }
        var counterClockwise = true
        for i in 0..<ringCount {
            let radius = spacing + (spacing + 10) * Double(i)
            let velocity = Double(min(i, 7) + 1) * 0.2
            let n = max(1, Int((radius * 2 * Double.pi) / spacing))
            let step = Double(360 / n) // divisione intera come nell'originale
            var a = 0.0
            repeat {
                let act = HypnosisActor()
                act.image = randomIcon()
                act.waveRadius = radius
                act.waveAngle = a
                act.opacity = 1
                act.velocity = velocity
                act.scale = IVPoint(x: iconScale, y: iconScale)
                act.waveAction = counterClockwise ? 0 : 1
                actors.append(act)
                a += step
            } while a < 360
            counterClockwise.toggle()
        }
    }

    public override func animateOneFrame() {
        for case let act as HypnosisActor in actors { moveActor(act) }
        sortActorsByDepth()
    }

    func moveActor(_ act: HypnosisActor) {
        if act.waveAction == 0 {
            act.waveAngle = (act.waveAngle + act.velocity).truncatingRemainder(dividingBy: 360)
        } else if act.waveAction == 1 {
            act.waveAngle = (act.waveAngle - act.velocity).truncatingRemainder(dividingBy: 360)
        }
        let cx = bounds.x + bounds.width * 0.5
        let cy = bounds.y + bounds.height * 0.5
        let th = act.waveAngle * degreesToRadians
        act.location = IVPoint(x: cx + act.waveRadius * cos(th), y: cy + act.waveRadius * sin(th))
        act.angle = act.waveAngle - 90
    }
}
