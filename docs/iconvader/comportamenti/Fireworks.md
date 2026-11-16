# Fireworks (FireworksBehavior + FireworksActor)

Source: `cls/FireworksBehavior.s`, `cls/FireworksActor.s`. Identifier `"Fireworks"`, localized name `"Fireworks"`.

## 1. What it looks like

Icons are launched one at a time from just below the bottom edge, at random x positions. Each one rises with a small constant sideways drift and slows down under gravity (-0.5 px/frame²). At the top of its arc (vertical speed reaches 0) it starts falling slowly and swells from 1x to almost 3x its normal size over 0 to 9 frames. Then it bursts into 8 copies of the same icon. The copies fly out in straight lines in the 8 compass directions (N, NE, E, SE, S, SW, W, NW), each at its own random speed, and shrink and fade linearly to nothing. Sparks are not affected by gravity.

## 2. State

```
FireworksActor : IVActor
  velocity  {x,y}  float   (+0x28)
  maxLife   int            (+0x30)
  currentLife int          (+0x34)
  blowFactor float         (+0x38)  -- declared but NEVER used by Fireworks code

FireworksBehavior : IVBehavior
  icons      NSArray        (+0x24)
  fireworks  NSMutableArray (+0x28)   rockets still rising/swelling
  sparks     NSMutableArray (+0x2c)   burst fragments
  maxSpeed   int            (+0x30)
  (inherited) bounds, density, lifeExpectancy, scaleFactor, actors (the render list)
```

The renderer draws `actors` in array order using a forward `objectEnumerator`, in both the Quartz and the OpenGL renderer. Later entries are drawn on top.

Notation:
- `rand()` is libc `random()`, a value in [0, 2^31-1].
- `%` is C truncating modulo. Every random number here is non-negative, so it is an ordinary modulo.
- `s = 128 * scaleFactor` is the nominal on-screen icon size in points.

## 3. Pseudocode

### initWithBounds:icons:density:lifeExpectancy:scaleFactor:
```
super.init(...)            // stores bounds, density, lifeExpectancy, scaleFactor; actors = []
icons     = icons (retained)
fireworks = []
sparks    = []
resetAnimation()
```
(This class does not call `srandom`.)

### resetAnimation   (also called by IVBehavior.setBounds:)
```
H = bounds.size.height                 // float
k = 10; apex = 105.0                   // apex(k) = k*(2k+1)/2  -> apex(10) = 105
while (H > apex):                      // strict >
    k += 1
    n = 2*k
    apex = (float)( n * (n - (n-1)*0.5) * 0.5 )     // == k*(2k+1)/2 == n(n+1)/4
maxSpeed = max(0, k - 11)
sparks.removeAll(); fireworks.removeAll(); actors.removeAll()
```
`apex(k)` is the height a rocket with initial vy = k gains before vy reaches 0 (k + (k-0.5) + ... + 0.5). So `k` is the smallest integer launch speed, at least 10, that reaches the full screen height. Rockets are given speeds no higher than k-2 (see below), so they never leave the top of the screen.
Sample values: H=768 → k=28, maxSpeed=17; H=900 → 19; H=1050/1080 → 22; H=1200 → 24; H=1440 → 27; H=184 → 3.

### animateOneFrame
```
if sparks.count <= 399:                           // (cmp 0x18f, skip if count > 399)
    if rand() % (101 - density) == 0:             // signed idiv; P = 1/(101-density) per frame
        a = new FireworksActor
        resetActor(a)
        fireworks.add(a); actors.add(a)
for a in fireworks:  moveActor(a, bounds)          // may remove a from fireworks/actors, may add sparks
for p in sparks:     moveSpark(p, bounds)          // includes sparks spawned this frame
actors.sortUsingSelector(compareDepth:)
```
With density 50, P = 1/51 per frame.

### resetActor:(a)    (launch a rocket)
```
s = 128.0 * scaleFactor                                   // float
a.image   = icons.count ? icons[ (uint)rand() % icons.count ] : nil     // rand #1 (only if count>0)
a.angle   = 0
a.scale   = (scaleFactor, scaleFactor)
a.opacity = 1.0
vy = (float)( rand() % maxSpeed + 10 )                    // rand #2 ; range [10, 10+maxSpeed-1]
vx = (float)( rand() % 9 - 4 )                            // rand #3 ; integer in [-4, 4]
a.velocity = (vx, vy)
x = (float)( fmod((double)rand(), (double)(bounds.width - 2*s)) + s )   // rand #4 ; x in [s, width-s)
y = -s
a.location = (x, y)
a.maxLife     = rand() % 10                               // rand #5 ; [0, 9]
a.currentLife = a.maxLife
```
Note the order of `rand()` calls above. Only `bounds.size` is used. `bounds.origin` is ignored, which assumes an origin of (0,0).

### moveActor:insideBounds:(a)   (rocket step; the bounds argument is unused)
```
loc = a.location; vel = a.velocity
if !(vel.y > 0):                         // vy <= 0 (or NaN): at or past apex
    cl = (float)a.currentLife
    if cl == 0:
        spawnSparksAtLocation(a.location, a.image)
        fireworks.remove(a); actors.remove(a)
        return                           // not moved this frame
    f = (cl / (float)a.maxLife) * -2.0 + 3.0     // 1.0 when cl==maxLife ... 3-2/maxLife when cl==1
    sc = f * scaleFactor
    a.scale = (sc, sc)
    a.currentLife = (int)(cl - 1.0)
    // fall through to the move
a.location = (loc.x + vel.x, loc.y + vel.y)      // move with OLD velocity
a.velocity = (vel.x, vel.y - 0.5)                // gravity, rockets only
```
vy starts as an integer and only ever has 0.5 subtracted from it, so it hits exactly 0.0 at the apex. On that frame:
- If maxLife = 0, the rocket explodes immediately and does not move.
- Otherwise it swells over maxLife frames while falling (vy = 0, -0.5, -1, ...) and explodes on the next frame.

The rocket is never culled by bounds. vx stays constant for its whole flight.

### spawnSparksAtLocation:image:(loc, img)
```
m    = (int)( (double)((float)lifeExpectancy * 300.0f) / 5000.0 )    // LE=1200 -> 72
life = rand() % m + 10                                                // one value shared by all 8 sparks; LE=1200 -> [10, 81]
for i in 0..7:
    p = new FireworksActor
    speed = (float)( rand() % 10 + 1 )                                // per spark, integer in [1, 10]
    p.image = img; p.angle = 0
    p.scale = (scaleFactor, scaleFactor); p.opacity = 1.0
    p.location = loc
    p.maxLife = life; p.currentLife = life
    p.velocity = switch i:
        0: ( 0,      +speed)     // N
        1: (+speed,  +speed)     // NE  (not normalised: diagonal is sqrt(2) faster)
        2: (+speed,   0)         // E
        3: (+speed,  -speed)     // SE
        4: ( 0,      -speed)     // S
        5: (-speed,  -speed)     // SW
        6: (-speed,   0)         // W
        7: (-speed,  +speed)     // NW
    sparks.add(p); actors.add(p)
```
The jump-table targets were decoded by hand: base 0x9b38 + {0x214,0x22e,0x248,0x262,0x285,0x2a3,0x2c5,0x2e3}. The `switch` has a default branch for i > 7 that skips `setVelocity`, but it can never be taken.

### moveSpark:insideBounds:(p)   (the bounds argument is unused)
```
cl = (float)p.currentLife
if cl == 0:
    sparks.remove(p); actors.remove(p); return
f = cl / (float)p.maxLife                 // 1.0 -> 1/maxLife
p.opacity = f
p.scale   = (f * scaleFactor, f * scaleFactor)
p.currentLife = (int)(cl - 1.0)
p.location = (loc.x + vel.x, loc.y + vel.y)   // velocity never changes (no gravity, no drag)
```
A spark is drawn for exactly `life` frames:
- Its first update happens in the same frame it is spawned, with f = 1.
- The last drawn frame has f = 1/life.
- It is removed on the frame after that.

### FireworksActor accessors
These are trivial getters and setters for velocity, maxLife and currentLife.

### FireworksActor compareDepth:(other)   (used by actors.sortUsingSelector)
```
if self.opacity == other.opacity:
    if self.identifier == other.identifier: return 0
    return (self.identifier < other.identifier) ? +1 : -1     // unsigned compare
return (self.opacity > other.opacity) ? +1 : -1
```
This sorts by **ascending opacity**, so the most opaque actors are drawn last, on top. Ties go by **descending identifier**, so older actors (lower id) are drawn on top. The opacity order is the reverse of the base `IVActor compareDepth:`, which sorts by descending opacity. `identifier` is a global counter that increments at every IVActor init.

## 4. Implementation notes (JS)

- Emulate `rand()` as `Math.floor(Math.random() * 2147483648)` and use integer `%`.
- To mimic the float32 maths, use `Math.fround`. In practice the visual result is the same without it.
- For mutation during enumeration, iterating over a snapshot (`for (a of fireworks.slice())`) is the simplest choice. See uncertainty U1.

## 5. Uncertainties / edge cases (flagged)

- **U1 – mutation while enumerating.** Both loops in `animateOneFrame` use `objectEnumerator` on the same NSMutableArray that `moveActor:` and `moveSpark:` `removeObject:` from. On 10.4 this is undefined behaviour. Most likely the CFArray-backed enumerator walks by index, so the element right after a removed one is skipped (not moved) for that frame. Snapshot iteration is a near-identical alternative, and the difference is at most a one-frame hitch for one spark or rocket. I did not verify the exact Foundation behaviour.
- **U2 – division by zero.**
  - `rand() % maxSpeed` traps (SIGFPE) when maxSpeed = 0, which happens for bounds height ≤ 126.5 pt.
  - `rand() % m` traps when lifeExpectancy < ~17.
  - `rand() % (101-density)` traps at density = 101, which is probably outside the preference range.

  A JS port should clamp each divisor to ≥ 1.
- **U3 – `fmod(rand(), width - 2s)`.** This gives NaN or a degenerate x if width ≤ 2s. That should not happen at real screen sizes.
- **U4 – bounds.origin is ignored.** All positions assume the bounds start at (0,0).
- `FireworksActor._blowFactor` exists in the ivar layout but no Fireworks method reads or writes it.
- Frame-based timing: every rate here is per call of `animateOneFrame`, which presumably runs at AnimationSpeed = 30 fps. I did not check that here.
