# Game of Life (GameOfLifeBehavior + GameOfLifeActor + GameOfLifeMatrix + GameOfLifeMatrixFreeze)

Source: `cls/GameOfLifeBehavior.s`, `cls/GameOfLifeActor.s`, `cls/GameOfLifeMatrix.s`, `cls/GameOfLifeMatrixFreeze.s`.
Identifier `"GameOfLife"`, localized name `"Game Of Life"`.

## 1. What it looks like

Icons sit on a fixed grid of square cells, centred on screen with 4-pt gaps, and play Conway's Life (B3/S23, edges are dead with no wrap-around). The board starts about 50% filled at random. New cells "pop in": staggered by a random delay, each grows from tiny to full size while fading in over 19 frames. After a short pause the next generation is computed. Dying cells, again staggered, swell to about 2.5x and fade out over 20 frames. After that the newborn cells pop in. When the pattern dies out, freezes, or repeats a state seen in the last 10 generations, every icon on the board blows up and fades out, and a new random board is seeded.

## 2. State

```
GameOfLifeActor : IVActor          column uint(+0x28) row uint(+0x2c) timeToLive int(+0x30) blowFactor float(+0x34)
GameOfLifeMatrix : NSObject        numberOfColumns uint(+4) numberOfRows uint(+8) data GameOfLifeActor*[cols*rows] (+0xc)
GameOfLifeMatrixFreeze : NSObject  data NSArray<NSNumber uint>(+4)
GameOfLifeBehavior : IVBehavior
   icons(+0x24) bornActors(+0x28) deadActors(+0x2c) matrix(+0x30) matrixFreezeQueue(+0x34)
   gridRect {x,y,w,h}(+0x38..+0x44) gamePhase int(+0x48) delay int(+0x4c) resetGame BOOL(+0x50)
```

The renderer draws `actors` (IVBehavior +0x20) in array order, so later entries appear on top. **GameOfLife never sorts `actors`** (see uncertainty U2), so the draw order is the order in which cells were appended.

Notation:
- `rand()` is libc `random()`, a value in [0, 2^31-1].
- `%` and `/` are C int ops, truncating.
- LE = lifeExpectancy, D = density, SF = scaleFactor.

## 3. Pseudocode

### GameOfLifeBehavior initWithBounds:(x,y,w,h) icons: density: lifeExpectancy: scaleFactor:
```
super.init(...)
s = SF * 128.0                         // float cell size
srandom(time(NULL))
icons = icons (retained)

// columns: extent(n) = n*s + (n-1)*4      (4-pt gutter between cells)
n = 0; ext = 0; prev = 0
while (w > ext):                       // float compare, strict
    prev = ext
    n += 1
    ext = (float)( n*s + (n-1)*4.0 )   // computed in double, stored float
cols = n - 1;  gridW = prev            // = extent(cols); the largest count whose extent is < w

// rows: same loop with h
... rows = m - 1; gridH = extent(rows)

gridRect.size   = (gridW, gridH)
gridRect.origin.y = roundf((h - gridH) * 0.5)
gridRect.origin.x = roundf((w - gridW) * 0.5)    // the passed origin (x,y) is NOT used
matrix            = GameOfLifeMatrix(cols, rows)  // zero-filled
matrixFreezeQueue = []
bornActors = []; deadActors = []
resetGame()
```
Example: 1024×768 at SF 0.6 gives s = 76.8 and pitch 80.8 → 12 cols × 9 rows, grid 965.6×723.2, origin (29, 22). At 1440×900 → 17×11.

GameOfLife does **not** override `resetAnimation`, so `setBounds:` does not rebuild the grid (the base method is a no-op).

### spawnActorAtColumn:col row:row → actor   (creates it, does NOT add it to any list)
```
a = new GameOfLifeActor          // blowFactor = 0, angle = 0 (zero-filled)
sf = SF
a.column = col; a.row = row
s = sf*128 (as double)
y = gridRect.origin.y + s*0.5 + row * (s + (row != 0 ? 4.0 : 0))     // == origin.y + s/2 + row*(s+4)
x = gridRect.origin.x + s*0.5 + col * (s + (col != 0 ? 4.0 : 0))     // == origin.x + s/2 + col*(s+4)
a.location = ((float)x, (float)y)          // row 0 is the BOTTOM row (Cocoa y-up)
a.image = icons.count ? icons[(uint)rand() % icons.count] : nil      // rand #1
a.scale = (sf*0.05, sf*0.05)               // never visible: it is overwritten before the actor is drawn
a.opacity = 1.0
a.timeToLive = rand() % (LE / 100)         // rand #2 ; LE=1200 -> [0, 11]
return a
```

### resetGame
```
actors.removeAll(); bornActors.removeAll(); deadActors.removeAll(); matrixFreezeQueue.removeAll()
matrix.reset()                              // release every cell, zero the array
for row in 0 ..< rows:                      // outer loop = rows (bottom to top)
    for col in 0 ..< cols:                  // inner loop = columns
        if rand() % 100 < D:                // signed compare; D=50 -> 50% fill
            bornActors.add( spawnActorAtColumn(col, row) )
gamePhase = 1
resetGame = NO
```

### animateOneFrame
```
switch gamePhase:
  case 1: birthPhase()
  case 2: thinkPhase()
  case 0: deathPhase()
  default: nothing
```

#### Phase 1 – birth animation
```
if bornActors.count == 0:
    delay = LE / 50                         // LE=1200 -> 24
    gamePhase = 2
    return
changed = NO
for a in bornActors:                        // objectEnumerator, removes inside the loop (see U1)
    if a.timeToLive != 0:
        a.timeToLive -= 1                   // staggered start
        continue
    // a.scale is read and discarded
    if a.blowFactor == 0:
        a.blowFactor = 0.05
        actors.add(a)                       // first becomes visible here
    a.blowFactor = (float)((double)a.blowFactor + 0.05)
    a.scale   = (a.blowFactor * SF, a.blowFactor * SF)
    a.opacity = a.blowFactor
    if a.blowFactor > 1.0:
        matrix.insertActor(a)               // matrix[a.row][a.column] = a
        bornActors.remove(a)
    changed = YES
if changed:
    bornActors.sortUsingSelector(compareDepth:)     // sorts bornActors, NOT actors (see U2)
```
In float32 the blowFactor goes 0.10, 0.15, ..., 0.9500002, 1.0000001. That is 19 visible frames with scale = bf·SF and opacity = bf. On the 19th frame bf = 1.0000001 > 1, so the cell is committed with scale ≈ SF and opacity ≈ 1 (slightly above 1, which clamps). In JS, use `Math.fround` or an integer step counter (bf = 0.05·(k+1) for k = 1..19). Plain double accumulation could land on a different step count.

#### Phase 2 – pause, then compute the next generation
```
delay -= 1
if delay != 0: return                       // pause: LE/50 frames
freeze = GameOfLifeMatrixFreeze(matrix)     // sorted list of linear indices (row*cols+col) of occupied cells
for f in matrixFreezeQueue:
    if freeze.isEqualToMatrixFreeze(f): goto KILL_ALL   // repeat within the last 10 generations
matrixFreezeQueue.add(freeze)
if matrixFreezeQueue.count > 10: matrixFreezeQueue.removeObjectAtIndex(0)   // keep <= 10 (FIFO)

// synchronous B3/S23 using the matrix, which is not modified during this scan
for row in 0 ..< rows:
    for col in 0 ..< cols:
        cell = matrix.actorAt(col, row)
        n = number of non-nil among the 8 neighbours (col±1, row±1)
            // out-of-range coordinates return nil (unsigned bounds check), so NO wrap-around
        if cell != nil:
            if n == 2 or n == 3: survive (nothing)
            else:
                deadActors.add(cell)
                cell.blowFactor = 0
                cell.timeToLive = rand() % (LE / 20)          // LE=1200 -> [0, 59]
        else if n == 3:
            bornActors.add( spawnActorAtColumn(col, row) )    // 2 rand() calls (image, ttl)
if bornActors.count == 0 and deadActors.count == 0: goto KILL_ALL   // static (or empty) board
gamePhase = 0
return

KILL_ALL:
    resetGame = YES
    deadActors.addObjectsFromArray(actors)  // deadActors is empty here, so = every cell on screen
    for a in deadActors:                    // in actors order
        a.blowFactor = 0
        a.timeToLive = rand() % (LE / 20)
    gamePhase = 0
```
The `rand()` calls happen in row-major order (bottom row first, left to right). For each cell they come as either (image, ttl) for a birth or (ttl) for a death.

The neighbour reads in the binary are in this order: (c-1,r-1) if r>0, (c-1,r), (c-1,r+1), then (c,r-1) if r>0, (c,r+1), then (c+1,r-1) if r>0, (c+1,r), (c+1,r+1). If c == 0 the whole left column is skipped and the count starts at 0. The explicit row/col == 0 guards are redundant with the bounds check. The order does not affect the result.

#### Phase 0 – death animation
```
if deadActors.count == 0:
    if actors.count == 0 and bornActors.count == 0: resetGame = YES
    if resetGame: resetGame(); return           // new random board, sets gamePhase = 1
    gamePhase = 1                               // go animate this generation's births
    return
changed = NO
for a in deadActors:                            // objectEnumerator, removes inside the loop (U1)
    if a.timeToLive != 0:
        a.timeToLive -= 1
        continue
    // a.scale is read and discarded
    a.blowFactor = (float)((double)a.blowFactor + 0.05)
    sc = (float)((a.blowFactor * 1.5 + 1.0) * (double)SF)
    a.scale   = (sc, sc)
    a.opacity = 1.0 - a.blowFactor
    if a.blowFactor > 1.0:
        matrix.removeActor(a)                   // matrix[a.row][a.column] = nil
        deadActors.remove(a)
        actors.remove(a)
    changed = YES
if changed:
    deadActors.sortUsingSelector(compareDepth:)     // sorts deadActors, NOT actors (U2)
```
In float32 the blowFactor goes 0.05, 0.10, ..., 0.9500002, then 1.0000001, at which point the cell is removed in the same frame. So there are 19 visible frames, scale (1.075 → 2.425)·SF and opacity (0.95 → ≈0.05), and the cell is gone on the 20th update. On the frame its timeToLive reaches 0 nothing changes visually: the cell keeps its birth scale ≈ SF and opacity ≈ 1 until the first increment.

#### Generation cycle
```
resetGame → [1] births: stagger rand()%(LE/100) frames, then 19 frames of growth
          → [1] bornActors empty → delay = LE/50, phase 2      (1 frame)
          → [2] LE/50 frames of pause; on the last one: freeze check + compute next generation
          → [0] deaths: stagger rand()%(LE/20) frames + 20 updates; when none remain → phase 1
          → [1] births of the new generation ... → [2] ...
KILL_ALL  → [0] every cell dies (staggered) → deadActors and actors empty → resetGame()
```
Deaths of a generation are fully animated before its births start.

### GameOfLifeMatrix
```
initWithColumns:c rows:r   cols=c; rows=r; data = calloc(c*r) (malloc+memset 0)
actorAtColumn:c row:r      return (c < cols && r < rows) ? data[r*cols + c] : nil     // unsigned compares
setActor:a atColumn:c row:r  if (c < cols && r < rows) { release old; data[r*cols+c] = retain(a) }
insertActor:a              setActor(a, a.column, a.row)
removeActor:a              setActor(nil, a.column, a.row)
reset                      release every non-nil cell; memset 0
data / numberOfColumns / numberOfRows  accessors
```

### GameOfLifeMatrixFreeze
```
matrixFreezeWithMatrix:m  → autoreleased initWithMatrix:m
initWithMatrix:m:  data = [ i for i in 0 ..< cols*rows if m.data[i] != nil ]   // NSNumber uint, ascending
isEqualToMatrixFreeze:o:
    if data.count != o.data.count: return NO
    for i in 0 ..< count: if !data[i].isEqualTo(o.data[i]): return NO
    return YES
```
This is plain set equality of the live-cell sets. The new state is compared against the up to 10 states stored **before** it is pushed. That detects still lifes, which the "no births and no deaths" check already catches, and oscillators with period ≤ 10. It also detects any return to one of the last 10 states. Gliders and other spaceships are not detected unless they die at an edge (edges are dead), turn into debris, or end up in a short cycle.

The selector names in the `isEqualToMatrixFreeze:` disassembly were mis-annotated as `-[FireworksBehavior dealloc]` / `-[FireworksActor maxLife]`. I resolved them by GOT address: 0xf334 = `@sel(data)` and 0xf10c = `@sel(count)`.

### GameOfLifeActor compareDepth:(other)
This is identical to `IVActor compareDepth:`:
```
if self.opacity == other.opacity:
    if self.identifier == other.identifier: return 0
    return (self.identifier < other.identifier) ? +1 : -1
return (other.opacity > self.opacity) ? +1 : -1        // descending opacity
```
It is only used to sort `bornActors` and `deadActors`. That sort affects the order in which actors are processed, and so the order in which born actors are appended to `actors`.

## 4. Implementation notes (JS)

- **Grid:**
  - `pitch = s + 4`
  - `cols = largest n with n*s + (n-1)*4 < w` (likewise rows with h)
  - centre with `Math.round` (roundf rounds halves away from zero, which matches `Math.round` for positive values)
  - cell centre = `origin + s/2 + i*pitch`
- **Rules:** B3/S23, finite board, dead border.
- **Draw order:** the order cells were added to `actors`. Dying cells grow to 2.5·s and overlap their neighbours, and whichever was appended later is drawn on top.

## 5. Uncertainties / edge cases (flagged)

- **U1 – removal during NSEnumerator iteration.** Born and dead actors are removed from `bornActors` / `deadActors` inside `for a in ...objectEnumerator`. On 10.4 this is undefined. Most likely the element right after a removed one is skipped for that frame: no ttl decrement and no growth step, so it lags by one frame. Iterating a snapshot is a close approximation. I did not verify which one Foundation actually did.
- **U2 – sorting the wrong array.** After each animation pass the code sorts `bornActors` or `deadActors`, never `actors`. This is almost certainly an original bug (the author probably meant `actors`). A faithful port should **not** sort `actors`. Re-ordering the born list does change the order of later appends into `actors`, which faintly affects z-order.
- **U3 – divide-by-zero or hang for small LifeExpectancy.**
  - LE < 100 makes `rand() % (LE/100)` trap.
  - LE < 20 makes `% (LE/20)` trap.
  - LE < 50 sets `delay = 0`, and since phase 2 decrements before testing it, it goes −1, −2, ... and effectively never finishes.

  At the default 1200 none of these happen. A port should clamp.
- **U4 – degenerate grid.** If s ≥ w (or h), cols (rows) = 0. The board is then always empty and the code cycles phase 1 → 2 → KILL_ALL → 0 → resetGame forever, drawing nothing.
- **U5 – bounds.origin and setBounds:.** The grid uses only the width and height passed to init. The bounds origin is ignored, and a later `setBounds:` does not rebuild the grid.
- `srandom(time(NULL))` is called once in init (not relevant for JS).
- Frame-based timing everywhere (presumably 30 fps from AnimationSpeed; not checked here).
