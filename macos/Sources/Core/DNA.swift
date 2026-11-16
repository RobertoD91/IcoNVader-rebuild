// DNA — DNABehavior + DNAHelix + DNAActor.
// Doppie eliche verticali di icone che ruotano sul proprio asse e scorrono in alto e in basso.

import Foundation

final class DNAActor: IVActor {
    var heightOffset = 0.0
    var angleOffset = 0.0

    /// Prima le icone piccole (lontane), a parità di scala quelle più in alto.
    override func compareDepth(_ other: IVActor) -> Int {
        if scale.x == other.scale.x {
            if location.y == other.location.y { return 0 }
            return other.location.y > location.y ? 1 : -1
        }
        return scale.x > other.scale.x ? 1 : -1
    }
}

final class DNAHelix {
    static let rungs = 20

    let icons: [IVIcon]
    let actors: [DNAActor]
    var location: IVPoint
    var velocity: Double
    var angle = 0.0
    let scale: Double
    var hasLived = false

    init(icons: [IVIcon], location: IVPoint, velocity: Double, scaleFactor: Double) {
        scale = scaleFactor * 0.25 + 0.25 // -[DNAHelix setScale:]
        func pick() -> IVIcon? { icons.isEmpty ? nil : icons[ivRandom() % icons.count] }
        var list: [DNAActor] = []
        var angleOffset = 0.0
        for i in 0..<Self.rungs {
            let h = Double(i) * (128 * scale)
            for off in [angleOffset, (angleOffset + 180).truncatingRemainder(dividingBy: 360)] {
                let a = DNAActor()
                a.image = pick()
                a.angleOffset = off
                a.heightOffset = h
                a.opacity = 1
                a.scale = IVPoint(x: scale, y: scale)
                list.append(a)
            }
            angleOffset += 30 // 30° di torsione per gradino
        }
        actors = list
        self.location = location
        self.velocity = velocity
        self.icons = icons
    }

    func moveInsideBounds(_ bounds: IVRect) {
        location.y += velocity
        angle = (1 + angle).truncatingRemainder(dividingBy: 360)
        let radius = 512 * scale
        for a in actors {
            let theta = (angle + a.angleOffset) * degreesToRadians
            a.location = IVPoint(x: location.x + cos(theta) * radius, y: location.y + a.heightOffset)
            let k = (sin(theta) * 0.5 + 1) * scale
            a.scale = IVPoint(x: k, y: k)
        }
        let rect = IVRect(x: location.x - 0.5 * radius, y: location.y,
                          width: radius, height: 128 * scale * Double(Self.rungs))
        if !hasLived {
            if rect.intersects(bounds) { hasLived = true }
        } else if !rect.intersects(bounds) {
            resetWithBounds(bounds)
        }
    }

    /// L'elica uscita dallo schermo rientra dal lato opposto con nuova velocità e nuove icone.
    func resetWithBounds(_ bounds: IVRect) {
        let mag = Double(ivRandom() % 3 + 1)
        velocity = velocity < 0 ? -mag : mag
        for a in actors { a.image = icons.isEmpty ? nil : icons[ivRandom() % icons.count] }
        if velocity > 0 {
            location.y = -128 * scale * Double(Self.rungs)
        } else {
            location.y = bounds.y + bounds.height - 10
        }
        hasLived = false
        moveInsideBounds(bounds)
    }
}

public final class DNABehavior: IVBehavior {
    public override class var identifier: String { "DNA" }
    public override class var displayName: String { "DNA" }

    var helixes: [DNAHelix] = []

    public required init(bounds: IVRect, icons: [IVIcon], density: Int, lifeExpectancy: Int, scaleFactor: Double) {
        super.init(bounds: bounds, icons: icons, density: density, lifeExpectancy: lifeExpectancy, scaleFactor: scaleFactor)
        resetAnimation()
    }

    public override func resetAnimation() {
        let t = scaleFactor * 0.25 + 0.25
        let spacing = t * 1024 + t * 256 + 10
        let W = bounds.width + 10
        let count = Int((W / spacing).rounded(.up))
        let leftover = W - Double(count) * spacing
        var x = (spacing + leftover) * 0.5
        helixes = []
        actors = []
        var dir = -1.0
        for _ in 0..<max(0, count) {
            let v = Double(ivRandom() % 3 + 1) * dir
            let helix = DNAHelix(icons: icons, location: IVPoint(x: x, y: 0), velocity: v, scaleFactor: scaleFactor)
            helixes.append(helix)
            actors.append(contentsOf: helix.actors as [IVActor])
            dir = -dir
            x += spacing
        }
    }

    public override func animateOneFrame() {
        for h in helixes { h.moveInsideBounds(bounds) }
        sortActorsByDepth()
    }
}
