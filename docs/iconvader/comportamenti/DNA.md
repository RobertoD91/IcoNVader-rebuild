# DNA behavior (DNABehavior + DNAHelix + DNAActor)

Identifier `"DNA"`, localized name key `"DNA"`.
Sources: `cls/DNABehavior.s`, `cls/DNAHelix.s`, `cls/DNAActor.s` (base: `cls/IVActor.s`, `cls/IVBehavior.s`).

## 1. What it looks like

A row of vertical double helices ("DNA strands") made of icons, evenly spaced across the screen width.
Each helix is 20 rungs tall; each rung has two icons on opposite sides of a vertical axis. The whole helix
spins about that axis (1 degree per frame), so icons swing left and right, grow larger as they come
"toward" the viewer and shrink as they go "behind", and front icons are drawn on top of back ones.
Adjacent helices scroll in opposite directions (down, up, down, ...) at 1, 2 or 3 px/frame. When a helix
has fully left the screen it is re-fed from the opposite edge with a new random speed (same direction)
and new random icons. Opacity is always 1 and icons are never rotated. Density and LifeExpectancy are
ignored; only ScaleFactor and the screen size matter.

## 2. Data

```
DNAActor : IVActor          // IVActor: location{x,y}, angle(deg), scale{x,y}, opacity, image, identifier
  heightOffset : float      // +0x28
  angleOffset  : float      // +0x2c

DNAHelix : NSObject
  icons    : NSArray        // +0x04 (retained)
  actors   : NSArray        // +0x08 (40 DNAActors)
  location : {x, y}         // +0x0c  x = axis of the helix, y = bottom rung
  velocity : float          // +0x14  px per frame along y (sign = direction)
  angle    : float          // +0x18  helix spin, degrees
  scale    : float          // +0x1c  NOTE: setter transforms its argument (see below)
  hasLived : bool           // +0x20

DNABehavior : IVBehavior    // IVBehavior: bounds{x,y,w,h}, density, lifeExpectancy, scaleFactor, actors
  icons   : NSArray         // +0x24
  helixes : NSMutableArray  // +0x28
```

`IVActor.identifier` is a global, monotonically increasing counter assigned at `-[IVActor init]`
(not used by DNA's own `compareDepth:` except indirectly – see below).

Bounds passed to the behavior are the screen view's `bounds` (origin normally (0,0)). Coordinates are
Cocoa: y up.

## 3. Pseudocode

All float math was done in 32-bit float with some intermediate steps in double; in JS just use doubles.
`random()` = libc random, 0..2^31-1. `pick(icons)` = `icons.count ? icons[random() % icons.count] : nil`
(unsigned modulo).

### DNABehavior

```
initWithBounds(bounds, icons, density, lifeExpectancy, scaleFactor):
    super.init(...)                 // stores bounds, density, lifeExpectancy, scaleFactor, actors = []
    self.icons   = icons
    self.helixes = []
    self.resetAnimation()

resetAnimation():
    t        = scaleFactor * 0.25 + 0.25          // same value DNAHelix.setScale will compute
    spacing  = t*1024 + t*256 + 10                // = 1280*t + 10  (helix pitch in x)
    W        = bounds.width + 10
    count    = (int) ceilf(W / spacing)           // number of helices
    leftover = W - count*spacing                  // <= 0
    x        = (spacing + leftover) * 0.5         // NOTE: bounds.origin.x is NOT added
    helixes.removeAll(); actors.removeAll()
    dir = -1.0
    for i in 0 ..< count:
        v = ((random() % 3) + 1) * dir            // -1/-2/-3 for i even, +1/+2/+3 for i odd
        h = DNAHelix.helixWithIcons(icons, location=(x, 0.0), velocity=v, scale=scaleFactor)
        helixes.add(h)
        actors.addAll(h.actors)                   // the behavior's actor list = concat of all helices
        dir = -dir
        x  += spacing

animateOneFrame():
    for h in helixes: h.moveInsideBounds(bounds)
    actors.sortUsingSelector(compareDepth:)      // DNAActor.compareDepth, see below
```

Example (ScaleFactor 0.6 → t = 0.4, spacing = 522):
1440 wide → 3 helices at x = 203, 725, 1247; 1920 → 4 at 182, 704, 1226, 1748; 800 → 2 at 144, 666.

`density` and `lifeExpectancy` are never read.

### DNAHelix

```
+helixWithIcons(icons, location, velocity, scale) = alloc.initWithIcons(...).autorelease

setScale(s):  self.scale = s * 0.25 + 0.25        // (double math, stored as float)
// so with the behavior passing scaleFactor, helix.scale == t (0.4 for default 0.6)

initWithIcons(icons, location, velocity, scaleArg):
    super.init()
    list = []
    self.setScale(scaleArg)                       // self.scale = t
    angleOffset = 0.0
    for i in 0 ..< 20:                            // 20 rungs
        h = (float)i * (128.0 * self.scale)       // rung height above helix.location.y
        a = DNAActor.actor()
        a.image        = pick(icons)
        a.angleOffset  = angleOffset              // NOT wrapped: 0,30,...,570
        a.heightOffset = h
        a.opacity      = 1.0
        a.scale        = (self.scale, self.scale)
        list.add(a)
        b = DNAActor.actor()
        b.image        = pick(icons)              // independent random pick
        b.angleOffset  = fmod(angleOffset + 180.0, 360.0)
        b.heightOffset = h
        b.opacity      = 1.0
        b.scale        = (self.scale, self.scale)
        list.add(b)
        angleOffset += 30.0                       // 30 deg twist per rung
    self.actors   = list                          // order: A0,B0,A1,B1,...,A19,B19 (40 actors)
    self.location = location
    self.velocity = velocity
    self.angle    = 0.0
    self.hasLived = NO
    self.icons    = icons
    // actor locations are left at (0,0) until the first moveInsideBounds
```

```
moveInsideBounds(bounds):
    location.y += velocity
    angle = (float) fmod(1.0 + angle, 360.0)      // +1 deg per frame, same sign for every helix
    for a in actors:
        theta = angle + a.angleOffset             // degrees
        s  = sin(theta * PI/180)                  // depth: +1 = front, -1 = back
        dx = cos(theta * PI/180) * 512.0 * scale  // radius of the helix = 512*t (204.8 px at t=0.4)
        a.location = (location.x + dx, location.y + a.heightOffset)
        k = (s * 0.5 + 1.0) * scale               // 0.5*t .. 1.5*t
        a.scale = (k, k)
        // opacity and angle untouched (1.0 and 0.0)

    // bounding box used only for the enter/leave test (note width is 512*t, NOT the full 1024*t swing)
    rect = { x: location.x - 0.5*(512*scale),
             y: location.y,
             w: 512*scale,
             h: 128*scale*20 }                    // 2560*t

    if !hasLived:
        if NSIntersectsRect(rect, bounds): hasLived = YES
        return
    else:   // hasLived == YES
        if !NSIntersectsRect(rect, bounds): self.resetWithBounds(bounds)
```

`NSIntersectsRect(a,b)` = false if either rect has w<=0 or h<=0; otherwise
`!(maxX(a) <= minX(b) || maxX(b) <= minX(a) || maxY(a) <= minY(b) || maxY(b) <= minY(a))`
(edge-touching counts as NOT intersecting).

```
resetWithBounds(bounds):
    mag = (random() % 3) + 1                      // 1, 2 or 3
    velocity = (velocity < 0) ? -mag : +mag       // direction preserved, speed re-randomised
    for a in actors: a.image = pick(icons)        // all 40 icons re-randomised
    if velocity > 0:
        location.y = -128.0 * scale * 20.0        // = -2560*t : whole helix just below the screen
    else:
        location.y = bounds.y + bounds.height - 10.0   // bottom rung 10 px below the top edge
    // location.x unchanged
    hasLived = NO
    self.moveInsideBounds(bounds)                 // immediately advances one more step (incl. angle +1)
```

Life cycle consequence: all helices start at y = 0 (covering the bottom 2560*t px, i.e. most of the
screen at t=0.4), become `hasLived` on frame 1, scroll, and when the box no longer intersects the
screen they wrap to the far edge. The two re-entry positions are asymmetric (upward helices re-enter
fully below the screen, downward ones re-enter with the bottom rung already 10 px inside the top).

### DNAActor.compareDepth(other)   (sort ascending → array order = back-to-front drawing order)

```
compareDepth(other):
    if self.scale.width == other.scale.width:
        if self.location.y == other.location.y: return 0           // NSOrderedSame
        return (other.location.y > self.location.y) ? +1 : -1      // higher y earlier (drawn first)
    return (self.scale.width > other.scale.width) ? +1 : -1        // smaller scale earlier
```

So the sort is: ascending by scale (smaller = farther = drawn first), ties broken by descending y.
The QuartzRenderer iterates the actor array with `objectEnumerator` (index 0 first) and paints in that
order, so later = on top. Sorting is redone every frame across all helices together.

JS equivalent: `actors.sort((a,b) => a.sx !== b.sx ? (a.sx > b.sx ? 1 : -1) : (a.y === b.y ? 0 : (b.y > a.y ? 1 : -1)))`.
(NSMutableArray sort was not guaranteed stable in 10.4; with ties = 0 only for identical scale *and* y,
stability is visually irrelevant.)

### Rendering (from QuartzRenderer, for reference)

Per actor: translate(location) → rotateByDegrees(angle) (CCW, y-up) → translate(-w*sx/2, -h*sy/2) →
scale(sx, sy) → draw image at (0,0) with `fraction = opacity` (NSCompositeSourceOver). I.e. the image is
centered on `location`, drawn at `imageSize * scale`. For DNA, angle is always 0 and opacity 1.
In a y-down canvas: `cy = H - y`.

## 4. Uncertainties / notes

- **Exactness**: all constants above are read directly from the code (0.25, 1024, 256, 10, 128, 20,
  30, 180, 360, 512, 0.5, 1.0, -128, 20, 10). No guessed values.
- `random() % 3` uses signed division on a non-negative value; equals JS `r % 3` with `r` in [0, 2^31).
  Use any uniform integer RNG; exact libc sequence only matters for bit-identical replay.
- The x-range used for the enter/leave rectangle (`512*t` wide, centered) is narrower than the actual
  icon swing (`±512*t`), and the rectangle height is `2560*t` while rungs span `0..2432*t` plus icon size.
  This is how the original works; it only affects the timing of wrap-around (by a few frames), keep it.
- Helix positions ignore `bounds.origin.x`, and the initial y = 0 ignores `bounds.origin.y`
  (the view bounds have origin (0,0) in practice, so no visible effect).
- `NSIntersectsRect` semantics given above are the documented/GNUstep ones; Apple's implementation is
  believed identical (not disassembled here — it's an AppKit/Foundation import).
- DNAActor's `angle` and `opacity` are never touched after init: angle is 0 because IVActor init leaves
  the ivar zeroed (ObjC zero-fills instances), opacity is set to 1.0 explicitly.
- If `icons` is empty, images are nil (renderer would draw nothing for that actor).
- Frame rate: one `moveInsideBounds` per `animateOneFrame`; all speeds are per frame (AnimationSpeed
  preference controls the frame interval elsewhere, not analysed here).
