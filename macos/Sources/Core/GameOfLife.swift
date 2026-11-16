// Game Of Life — GameOfLifeBehavior + GameOfLifeActor + GameOfLifeMatrix + GameOfLifeMatrixFreeze.
// Il gioco della vita di Conway (B3/S23, bordi morti) su una griglia di icone.

import Foundation

final class GameOfLifeActor: IVActor {
    var column = 0
    var row = 0
    var timeToLive = 0
    var blowFactor: Float = 0 // float32 come nell'originale: 19 passi di crescita esatti
}

final class GameOfLifeMatrix {
    let numberOfColumns: Int
    let numberOfRows: Int
    private(set) var data: [GameOfLifeActor?]

    init(columns: Int, rows: Int) {
        numberOfColumns = columns
        numberOfRows = rows
        data = Array(repeating: nil, count: columns * rows)
    }

    func actorAt(_ c: Int, _ r: Int) -> GameOfLifeActor? {
        if c < 0 || r < 0 || c >= numberOfColumns || r >= numberOfRows { return nil }
        return data[r * numberOfColumns + c]
    }

    func setActor(_ a: GameOfLifeActor?, _ c: Int, _ r: Int) {
        if c < 0 || r < 0 || c >= numberOfColumns || r >= numberOfRows { return }
        data[r * numberOfColumns + c] = a
    }

    func insertActor(_ a: GameOfLifeActor) { setActor(a, a.column, a.row) }
    func removeActor(_ a: GameOfLifeActor) { setActor(nil, a.column, a.row) }
    func reset() { data = Array(repeating: nil, count: data.count) }

    /// GameOfLifeMatrixFreeze: indici lineari delle celle vive, in ordine.
    func freeze() -> [Int] { data.indices.filter { data[$0] != nil } }
}

public final class GameOfLifeBehavior: IVBehavior {
    public override class var identifier: String { "GameOfLife" }
    public override class var displayName: String { "Game Of Life" }

    private enum Phase { case death, birth, think }
    private static let freezeQueueLength = 10
    private static let gutter = 4.0

    var bornActors: [GameOfLifeActor] = []
    var deadActors: [GameOfLifeActor] = []
    var matrixFreezeQueue: [[Int]] = []
    private var gamePhase = Phase.birth
    var delay = 0
    var resetGameFlag = false
    var gridRect = IVRect(x: 0, y: 0, width: 0, height: 0)
    var matrix = GameOfLifeMatrix(columns: 0, rows: 0)

    public required init(bounds: IVRect, icons: [IVIcon], density: Int, lifeExpectancy: Int, scaleFactor: Double) {
        super.init(bounds: bounds, icons: icons, density: density, lifeExpectancy: lifeExpectancy, scaleFactor: scaleFactor)
        buildGrid()
    }

    /// L'originale calcolava la griglia solo all'avvio; qui la si ricostruisce anche al ridimensionamento.
    public override func setBounds(_ bounds: IVRect) {
        self.bounds = bounds
        buildGrid()
    }

    func buildGrid() {
        let s = scaleFactor * 128
        func extent(_ limit: Double) -> (Int, Double) {
            var n = 0
            var ext = 0.0
            var prev = 0.0
            while limit > ext {
                prev = ext
                n += 1
                ext = Double(n) * s + Double(n - 1) * Self.gutter
            }
            return (max(0, n - 1), prev)
        }
        let (cols, gridW) = extent(bounds.width)
        let (rows, gridH) = extent(bounds.height)
        gridRect = IVRect(x: ((bounds.width - gridW) * 0.5).rounded(),
                          y: ((bounds.height - gridH) * 0.5).rounded(),
                          width: gridW, height: gridH)
        matrix = GameOfLifeMatrix(columns: cols, rows: rows)
        resetGame()
    }

    func spawnActorAt(_ col: Int, _ row: Int) -> GameOfLifeActor {
        let a = GameOfLifeActor()
        let sf = scaleFactor
        let s = sf * 128
        a.column = col
        a.row = row
        a.location = IVPoint(x: gridRect.x + s * 0.5 + Double(col) * (s + Self.gutter),
                             y: gridRect.y + s * 0.5 + Double(row) * (s + Self.gutter)) // riga 0 in basso
        a.image = randomIcon()
        a.scale = IVPoint(x: sf * 0.05, y: sf * 0.05)
        a.opacity = 1
        a.timeToLive = ivRandom() % max(1, lifeExpectancy / 100)
        return a
    }

    func resetGame() {
        actors = []
        bornActors = []
        deadActors = []
        matrixFreezeQueue = []
        matrix.reset()
        for row in 0..<matrix.numberOfRows {
            for col in 0..<matrix.numberOfColumns where ivRandom() % 100 < density {
                bornActors.append(spawnActorAt(col, row))
            }
        }
        gamePhase = .birth
        resetGameFlag = false
    }

    public override func animateOneFrame() {
        switch gamePhase {
        case .birth: birthPhase()
        case .think: thinkPhase()
        case .death: deathPhase()
        }
    }

    private func birthPhase() {
        if bornActors.isEmpty {
            delay = max(1, lifeExpectancy / 50)
            gamePhase = .think
            return
        }
        var changed = false
        for a in bornActors {
            if a.timeToLive != 0 {
                a.timeToLive -= 1
                continue
            }
            if a.blowFactor == 0 {
                a.blowFactor = 0.05
                actors.append(a) // diventa visibile qui
            }
            a.blowFactor = Float(Double(a.blowFactor) + 0.05)
            let bf = Double(a.blowFactor)
            a.scale = IVPoint(x: bf * scaleFactor, y: bf * scaleFactor)
            a.opacity = bf
            if a.blowFactor > 1 {
                matrix.insertActor(a)
                bornActors.removeObject(a)
            }
            changed = true
        }
        // Nell'originale si ordina la lista delle nascite, non quella disegnata.
        if changed { bornActors.sort { $0.compareDepth($1) < 0 } }
    }

    private func thinkPhase() {
        delay -= 1
        if delay != 0 { return }

        let freeze = matrix.freeze()
        if matrixFreezeQueue.contains(freeze) {
            killAll()
            return
        }
        matrixFreezeQueue.append(freeze)
        if matrixFreezeQueue.count > Self.freezeQueueLength { matrixFreezeQueue.removeFirst() }

        let deathTtl = max(1, lifeExpectancy / 20)
        for row in 0..<matrix.numberOfRows {
            for col in 0..<matrix.numberOfColumns {
                var n = 0
                for dc in -1...1 {
                    for dr in -1...1 where (dc != 0 || dr != 0) && matrix.actorAt(col + dc, row + dr) != nil {
                        n += 1
                    }
                }
                if let cell = matrix.actorAt(col, row) {
                    if n != 2 && n != 3 {
                        deadActors.append(cell)
                        cell.blowFactor = 0
                        cell.timeToLive = ivRandom() % deathTtl
                    }
                } else if n == 3 {
                    bornActors.append(spawnActorAt(col, row))
                }
            }
        }
        if bornActors.isEmpty && deadActors.isEmpty {
            killAll()
            return
        }
        gamePhase = .death
    }

    /// Stallo o ciclo: tutte le icone esplodono e si riparte con una nuova scacchiera.
    private func killAll() {
        resetGameFlag = true
        let deathTtl = max(1, lifeExpectancy / 20)
        deadActors.append(contentsOf: actors.compactMap { $0 as? GameOfLifeActor })
        for a in deadActors {
            a.blowFactor = 0
            a.timeToLive = ivRandom() % deathTtl
        }
        gamePhase = .death
    }

    private func deathPhase() {
        if deadActors.isEmpty {
            if actors.isEmpty && bornActors.isEmpty { resetGameFlag = true }
            if resetGameFlag {
                resetGame()
                return
            }
            gamePhase = .birth
            return
        }
        var changed = false
        for a in deadActors {
            if a.timeToLive != 0 {
                a.timeToLive -= 1
                continue
            }
            a.blowFactor = Float(Double(a.blowFactor) + 0.05)
            let bf = Double(a.blowFactor)
            let sc = (bf * 1.5 + 1) * scaleFactor // fino a circa 2,5×
            a.scale = IVPoint(x: sc, y: sc)
            a.opacity = 1 - bf
            if a.blowFactor > 1 {
                matrix.removeActor(a)
                deadActors.removeObject(a)
                actors.removeObject(a)
            }
            changed = true
        }
        if changed { deadActors.sort { $0.compareDepth($1) < 0 } }
    }
}
