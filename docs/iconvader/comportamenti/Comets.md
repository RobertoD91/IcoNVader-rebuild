# Comets (CometsBehavior + CometsActor)

Source: `cls/CometsBehavior.s`, `cls/CometsActor.s`, base classes `cls/IVBehavior.s`, `cls/IVActor.s`.
Identifier string: `@"Comets"`; display name: `localizedStringForKey:@"Comets" value:@"" table:nil`.

## 1. What it looks like

Icons fly in from the four screen edges in straight lines (horizontal/vertical, or diagonal), at 3 to 12 px per
frame on each axis. Each one starts at full size (scaleFactor) and full opacity and shrinks and fades linearly
toward nothing over its short life. When it drops to 5% or below, or leaves the screen after having been on it,
it respawns just outside a random edge with a new icon. Icons never rotate. All comets spawn at once at
startup, so the first wave arrives together.
Because of how the code works, diagonal comets only ever drift **rightward or upward** (see U1).

## 2. Data

```
CometsBehavior : IVBehavior
  _bounds {x,y,w,h}   (+0x04..+0x10)   float
  _density            (+0x14)          int
  _lifeExpectancy     (+0x18)          int
  _scaleFactor        (+0x1c)          float
  _actors             (+0x20)          NSMutableArray
  _icons              (+0x24)          NSArray of NSImage   (retained in init, released in dealloc)

CometsActor : IVActor
  (IVActor) _identifier uint, _location {x,y}, _angle (deg), _scale {x,y}, _opacity, _image, _userInfo
  _velocity  {x,y} float   (+0x28)
  _timeToLive int          (+0x30)
  _blowFactor float        (+0x34)
  _hasLived  BOOL (char)   (+0x38)
```
CometsActor only has plain getters and setters, with no logic of its own.
`IVActor.init`: `_identifier = globalCounter++` (a static counter that starts at 0 and is shared by all actors),
`_userInfo = new dict`. Everything else is zero-filled by alloc.

`rnd()` below is libc `random()`: an integer in `[0, 2^31-1]`, never negative, so every `%` below is a plain
non-negative modulo, even though the compiler emitted signed-modulo fix-up code.
The order of `rnd()` calls is listed exactly, for anyone who wants to reproduce a BSD `random()` stream.

## 3. Pseudocode

### init (initWithBounds:icons:density:lifeExpectancy:scaleFactor:)
```
super.init(...)             // IVBehavior: stores bounds, density, lifeExpectancy, scaleFactor; actors = []
_icons = icons (retain)
self.resetAnimation()
```
`IVBehavior.setBounds:` stores the bounds and also calls `resetAnimation`.

### resetAnimation
```
n = trunc( (double)bounds.w * 0.0078125 * (((double)density + 3.0) / 10.0) )
     // = floor(width/128 * (density+3)/10); uses WIDTH only, not height
     // defaults: density 50, width 1440  ->  11.25 * 5.3 = 59.6  -> 59 comets
actors.removeAllObjects()
for i in 0 ..< n:
    a = new CometsActor
    self.resetActor(a)
    actors.add(a)
```

### resetActor(a)
```
sf = _scaleFactor
W  = _bounds.w ; H = _bounds.h            // bounds.origin is NOT used here
side = rnd() % 4
switch side:
  case 0:  // LEFT edge, moving right
      x = -128.0f * sf                     // float multiply
      y = fmod((double)rnd(), H)
      dir = (1.0, rnd() % 2)              // dir.y is 0 or 1 (never -1)
  case 1:  // TOP edge, moving down
      x = fmod((double)rnd(), W)
      y = (float)(H + sf * 128.0)          // double math, then rounded to float
      dir = (rnd() % 2, -1.0)              // dir.x is 0 or 1
  case 2:  // RIGHT edge, moving left
      x = (float)(W + sf * 128.0)
      y = fmod((double)rnd(), H)
      dir = (-1.0, rnd() % 2)              // dir.y is 0 or 1
  case 3:  // BOTTOM edge, moving up
      x = fmod((double)rnd(), W)
      y = -128.0f * sf
      dir = (rnd() % 2, 1.0)               // dir.x is 0 or 1
   // In each case the position rnd() comes first, then the direction rnd().

if _icons.count != 0:
    a.image = _icons[ rnd() % _icons.count ]     // unsigned modulo
else:
    a.image = nil                                 // (no rnd() call)
a.angle      = 0
a.scale      = (sf, sf)
a.blowFactor = 1.0
a.opacity    = 1.0
r1 = rnd(); r2 = rnd()                            // in this order
a.velocity   = ( (r2 % 10 + 3) * dir.x ,          // vx uses the SECOND call
                 (r1 % 10 + 3) * dir.y )          // vy uses the FIRST call
                 // each axis gets its own random speed of 3..12 px/frame (0 if that dir component is 0)
a.timeToLive = (rnd() % _lifeExpectancy) / 5      // integer division; LE=1200 -> 0..239
a.location   = (x, y)
a.hasLived   = NO
```
Order of rnd() calls: side, position, direction, [icon], r1 (vy), r2 (vx), ttl.

### moveActor(a, insideBounds: b)
The `b` argument (always `[self bounds]`) is ignored. The method reads the `_bounds` ivar directly.
```
loc  = a.location
blow = (float)( (double)a.blowFactor + (-1.0 / (double)a.timeToLive) )   // linear decrease
a.blowFactor = blow
a.location   = (loc.x + a.velocity.x, loc.y + a.velocity.y)              // float adds
a.scale      = (blow * _scaleFactor, blow * _scaleFactor)
a.opacity    = blow
if NSPointInRect(a.location, _bounds):
    a.hasLived = YES                       // only ever set here; cleared only by resetActor
```

### animateOneFrame
```
for a in actors (forward enumeration):
    self.moveActor(a, insideBounds: self.bounds)
    blow = a.blowFactor
    if blow <= 0.05:                       // (double compare; a NaN would count as "alive")
        self.resetActor(a)
    else if a.hasLived and not NSPointInRect(a.location, _bounds):
        self.resetActor(a)
    // else: keep it (also covers comets still approaching from off-screen, hasLived == NO)
actors.sortUsingSelector(compareDepth:)
```

### IVActor.compareDepth: (shared, used by the sort)
```
compare(A, B):
    if A.opacity == B.opacity:
        if A.identifier == B.identifier: return 0
        return (A.identifier < B.identifier) ? +1 : -1     // unsigned compare
    return (B.opacity > A.opacity) ? +1 : -1
```
The result is that the array is sorted by **opacity descending**, with ties broken by **identifier descending**.
Both renderers (Quartz and OpenGL) iterate `actors` with `objectEnumerator`, which is forward order. So the most
opaque comets are drawn first (underneath) and the faintest are drawn last (on top).

`NSPointInRect(p, r)` (Cocoa) checks `p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY`, a half-open
rectangle that is false for an empty rect.

### Lifetime summary
- A comet lives about `0.95 * ttl` frames, with ttl from 0 to `floor((LE-1)/5)` (0..239 at the default
  LE=1200). Exact count: repeat `b = fround(b - 1/ttl)` from 1.0 until `b <= 0.05`.
- Comets with a small ttl die before their centre reaches the screen, because they spawn
  `128*sf` px (76.8 px at the default) outside the edge and move only 3..12 px/frame. Those respawn without being
  noticed.
- ttl == 0 gives `-1/0 = -inf`, so blowFactor becomes `-inf` and the comet is reset in the same frame, before
  it is drawn. In JS, `-1/0` is also `-Infinity`, so this matches naturally.

## 4. Uncertainties and quirks (flagged)

- **U1 (direction bias, faithful):** the perpendicular direction component is `random() % 2`, which is 0 or 1 and never -1.
  So comets from the left or right edge move either horizontally or **upward**, and comets from the top or bottom
  move vertically or **rightward**. This was probably meant to be ±1, but the binary is clear. Reproduce it as-is.
- **U2:** spawn positions use only `bounds.w` and `bounds.h` and ignore `bounds.origin`, while the in/out test uses the
  full `_bounds` rect, origin included. In the screensaver the origin is always (0,0), so this makes no difference.
- **U3:** `_lifeExpectancy == 0` would cause an integer divide-by-zero (SIGFPE) in the original. Guard against it in JS.
- **U4:** `_icons.count == 0` leaves `image = nil`. Not relevant if icons are always provided.
- **U5:** the actor count uses only the screen width, not the area.
- **U6:** frame timing (AnimationSpeed 30) belongs to the host view, not this class. All motion here is in
  px per `animateOneFrame` call.
- The comet's `_hasLived` getter returns a byte. animateOneFrame tests `hasLived == 1` exactly. Since only 0 and 1 are
  ever stored, this is the same as a boolean test.
