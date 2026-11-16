// Banco di prova del nucleo Swift (compilabile anche su Linux).
//
// Uso: iconvader-test <Comportamento> <fotogrammi> <seme> [larghezza altezza]
// Esegue il comportamento con un generatore casuale deterministico (mulberry32, identico a quello
// di macos/Tests/reference.js) e stampa lo stato di tutti gli attori in JSON, una riga per attore,
// ordinati per identificatore. Lo script compare.sh confronta l'output con quello della versione web.

import Foundation

/// mulberry32: stesso algoritmo di reference.js, restituisce [0, 1).
struct Mulberry32 {
    var state: UInt32
    mutating func next() -> Double {
        state = state &+ 0x6D2B_79F5
        var t = (state ^ (state >> 15)) &* (1 | state)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}

let args = CommandLine.arguments
guard args.count >= 4, let frames = Int(args[2]), let seed = UInt32(args[3]) else {
    FileHandle.standardError.write("uso: iconvader-test <Comportamento> <fotogrammi> <seme> [larghezza altezza]\n".data(using: .utf8)!)
    exit(2)
}
let width = args.count > 5 ? Double(args[4]) ?? 1440 : 1440
let height = args.count > 5 ? Double(args[5]) ?? 900 : 900

var rng = Mulberry32(state: seed)
IVRandom.source = { Int((rng.next() * 2_147_483_648).rounded(.down)) }

let icons = (0..<7).map { IVIcon(index: $0, width: 128, height: 128) }
let cls = behaviorClass(forIdentifier: args[1])
guard cls.identifier == args[1] else {
    FileHandle.standardError.write("comportamento sconosciuto: \(args[1])\n".data(using: .utf8)!)
    exit(2)
}
let behavior = cls.init(bounds: IVRect(x: 0, y: 0, width: width, height: height),
                        icons: icons, density: 50, lifeExpectancy: 1200, scaleFactor: 0.6)
for _ in 0..<frames { behavior.animateOneFrame() }

func fmt(_ v: Double) -> String { String(format: "%.6f", v) }
for a in behavior.actors.sorted(by: { $0.identifier < $1.identifier }) {
    precondition(a.location.x.isFinite && a.location.y.isFinite, "posizione non finita")
    print("{\"id\":\(a.identifier),\"x\":\(fmt(a.location.x)),\"y\":\(fmt(a.location.y)),\"angle\":\(fmt(a.angle)),\"sx\":\(fmt(a.scale.x)),\"sy\":\(fmt(a.scale.y)),\"opacity\":\(fmt(a.opacity)),\"image\":\(a.image?.index ?? -1)}")
}
