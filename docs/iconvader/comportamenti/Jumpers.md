# Jumpers (JumpersBehavior + JumpersActor)

Source: `cls/JumpersBehavior.s`, `cls/JumpersActor.s`, base classes `cls/IVBehavior.s`, `cls/IVActor.s`.
Identifier string: `@"Jumpers"`; display name: `localizedStringForKey:@"Jumpers" value:@"" table:nil`.

## 1. What it looks like

Icons pop into existence at random spots in the upper part of the screen: each grows from a tiny dot to full
size while fading in, over about 19 frames. Then it falls under constant gravity (1 px/frame²), bounces off the
bottom of the screen with no energy loss, and drifts sideways at -4..+4 px/frame, bouncing off the left and right
edges. There is no ceiling. On each floor bounce the icon has a 25% chance to reverse horizontal direction, and it
picks a random trick: no spin, a full forward somersault, or a full backward somersault. The somersault happens
around the top of each hop, while |vy| is at most 1/1.3 of the take-off speed. After its lifetime (up to
LifeExpectancy frames) it "blows up": over 20 frames it swells to almost 6x its size (5.75x on the last frame drawn) while fading out, and then respawns
somewhere else.

## 2. Data

```
JumpersBehavior : IVBehavior
  _bounds {x,y,w,h}, _density int, _lifeExpectancy int, _scaleFactor float, _actors   (see IVBehavior)
  _icons  (+0x24) NSArray of NSImage  (retained in init, released in dealloc)

JumpersActor : IVActor
  _velocity {x,y}           float  (+0x28)
  _timeToLive               int    (+0x30)
  _rotationAction           int    (+0x34)   0 = none, 1 = forward flip, 2 = backward flip
  _rotationVelocityRange    float  (+0x38)
  _blowAction               int    (+0x3c)   0 = appearing, 1 = alive, 2 = exploding, 3 = dead (reset)
  _blowFactor               float  (+0x40)
```
JumpersActor only has plain getters and setters. Fields not set by resetActor start at zero
(ObjC alloc zero-fills): opacity = 0, angle = 0, rotationAction = 0, rotationVelocityRange = 0.
`IVActor.init`: `_identifier = globalCounter++`.

`rnd()` is libc `random()`, which is never negative (0 .. 2^31-1), so `%` is a plain modulo.
Math is float32 unless marked "double". To match bit-for-bit in JS, wrap float results in `Math.fround`.

## 3. Pseudocode

### init (initWithBounds:icons:density:lifeExpectancy:scaleFactor:)
```
super.init(...)       // stores bounds, density, lifeExpectancy, scaleFactor; actors = []
_icons = icons (retain)
self.resetAnimation()
```
(`setBounds:` also calls resetAnimation.)

### resetAnimation (identical to Comets)
```
n = trunc( (double)bounds.w * 0.0078125 * (((double)density + 3.0) / 10.0) )   // width/128 * (density+3)/10
actors.removeAllObjects()
for i in 0 ..< n:
    a = new JumpersActor
    self.resetActor(a)
    actors.add(a)
```

### resetActor(a)
```
b  = self.bounds                // only b.w and b.h are used (origin ignored)
s0 = (float)((double)_scaleFactor * 0.05)
if _icons.count != 0:
    a.image = _icons[ rnd() % _icons.count ]          // unsigned modulo
else:
    a.image = nil
y = (float)( fmod((double)rnd(), (double)b.h - 70.0) + 80.0 )   // FIRST rnd -> y in [80, h+10)
x = (float)( fmod((double)rnd(), (double)b.w - 40.0) + 10.0 )   // SECOND rnd -> x in [10, w-30)
a.location   = (x, y)
a.scale      = (s0, s0)
a.velocity   = ( (float)(rnd() % 9 - 4), 0.0 )                  // vx in -4..+4 (integer values), vy = 0
a.timeToLive = rnd() % _lifeExpectancy                          // 0 .. LE-1   (no /5, unlike Comets)
a.blowAction = 0
a.blowFactor = 0.05f
// NOT touched: opacity, angle, rotationAction, rotationVelocityRange   (see U1, U2)
```
Order of rnd() calls: [icon], y, x, vx, ttl.

### moveActor(a, insideBounds: B)       — B = [self bounds], passed by value
Only `B.origin.x` and `B.size.width` are used. `B.origin.y` and `B.size.height` are not read.
```
sf  = _scaleFactor
loc = a.location
v   = a.velocity
x   = loc.x + v.x
y   = loc.y + v.y
a.location = (x, y)                                   // move first, using the OLD velocity

img   = a.image.size                                  // NSImage size (e.g. 128x128)
halfW = 0.5 * (img.w * sf)                            // uses _scaleFactor, NOT the actor's current scale
halfH = (sf * img.h) * 0.5

vx = v.x
// ---- floor / gravity ----
if halfH > y and v.y < 0:                             // centre went below halfH (floor at absolute y = 0)
    vy = -v.y                                         // perfectly elastic bounce, no gravity this frame
    if (rnd() & 3) == 0:  vx = -vx                    // 25%: reverse horizontal direction
    a.rotationVelocityRange = abs( (float)((double)vy / 1.3) )
    a.rotationAction        = rnd() % 3               // 0,1,2
else:
    vy = v.y - 1.0                                    // gravity, 1 px/frame^2

// ---- side walls ----
if x < B.x + halfW and vx < 0:
    vx = -vx
else if x > (B.w - B.x) - halfW and vx > 0:          // NOTE "w - x", not "x + w" (U4)
    vx = -vx
a.velocity = (vx, vy)
// no ceiling test

// ---- blow state machine ----
blow = a.blowFactor
switch a.blowAction:
  case 0:   // appearing
      blow = (float)((double)blow + 0.05)
      if blow > 1.0:  a.blowAction = 1;  blow = 0.0
  case 1:   // alive
      blow = (float)((double)blow + 1.0 / (double)a.timeToLive)    // ttl==0 -> +inf -> leaves at once
      if blow > 1.0:  a.blowAction = 2;  blow = 0.0
  case 2:   // exploding
      blow = (float)((double)blow + 0.05)
      if blow > 1.0:  a.blowAction = 3                // blow is NOT reset (stays ~1.0000001)
  default:  // 3: unchanged
a.blowFactor = blow

// ---- rotation (vy = the NEW vy just stored) ----
R = a.rotationVelocityRange
if R < abs(vy):              angle = 0                // also if either value is NaN
else if R <= 0:              angle = 0
else switch a.rotationAction:
    case 1:  angle = (1.0 - vy / R) * 180.0           // vy: +R -> -R  ==>  angle 0 -> 360 (increasing)
    case 2:  angle = (vy / R + 1.0) * 180.0           // vy: +R -> -R  ==>  angle 360 -> 0 (decreasing)
    default: angle = 0
a.angle = angle               // degrees

// ---- scale (blowAction re-read AFTER the state machine) ----
switch a.blowAction:
  case 0:  s = blow * sf
  case 1:  s = sf
  case 2:  s = (float)( ((double)(blow * 5.0f) + 1.0) * (double)sf )    // 1*sf .. 6*sf
  default: s = sf                                                      // includes 3
a.scale = (s, s)              // a.scale getter is also called and its result discarded (no effect)

// ---- opacity (blowAction re-read again) ----
switch a.blowAction:
  case 0:  a.opacity = blow
  case 2:  a.opacity = 1.0 - blow
  default: a.opacity = 1.0    // 1 and 3
```

### animateOneFrame
```
for a in actors (forward enumeration):
    self.moveActor(a, insideBounds: self.bounds)
    if a.blowAction == 3:
        self.resetActor(a)
actors.sortUsingSelector(compareDepth:)
```
`compareDepth:` (IVActor): sorts by **opacity descending**, ties broken by **identifier descending**. The renderers draw
in forward array order, so the most opaque icons are drawn first (underneath) and fading ones on top.
See Comets.md for the exact comparator.

### Timeline of one actor (exact with float32 accumulation)
| phase | blowAction | frames | scale | opacity |
|---|---|---|---|---|
| appear | 0 | 18 frames showing blow = 0.10, 0.15 … 0.95; on the 19th, blow reaches 1.0000001 and the actor switches to phase 1 (shown at sf, opacity 1) | blow·sf | blow |
| alive | 1 | about ttl frames (blow goes 0 → >1 in steps of 1/ttl; ttl=0 gives 1 frame, ttl=1 gives 2 frames; otherwise ttl or ttl+1 depending on float rounding, so emulate with fround) | sf | 1 |
| explode | 2 | the switch frame shows blow = 0 (sf, opacity 1), then 19 frames of blow 0.05 … 0.95 (scale 1.25sf … 5.75sf, opacity 0.95 … 0.05); on the 20th increment blow = 1.0000001 and the action becomes 3 (that frame is drawn after the reset, see U2), so 6·sf and opacity 0 are never actually drawn | (5·blow+1)·sf | 1−blow |
| dead | 3 | reset in the same animateOneFrame | — | — |

Movement, gravity, bouncing and rotation continue in every phase, including while appearing and exploding.

### Somersault geometry
At a bounce, `R = |vy_bounce| / 1.3`. Right after the bounce `|vy| > R`, so angle = 0. Gravity lowers vy by 1 per frame.
Once `vy <= R` the flip starts: angle goes 0 → 180 at the apex (vy = 0) → 360 when vy = −R. After that `|vy| > R` again
and angle snaps to 0, which is the same orientation as 360, so the motion looks smooth. The flip takes about `2R` frames,
centred on the apex.

## 4. Uncertainties and quirks (flagged, all faithful to the binary)

- **U1 – stale rotation after respawn:** resetActor does not clear `rotationAction` or `rotationVelocityRange`.
  A respawned actor starts with vy = 0, which is within the old R (when R > 0). If its old rotationAction was 1 or 2,
  it appears **upside down (angle 180)** and completes the second half of a flip as it starts falling, until
  |vy| > old R. Actors created for the first time (R = 0, action 0) start upright. This is probably unintended
  but it is what the code does.
- **U2 – one-frame glitch on respawn:** in the frame where the explosion ends, moveActor sets
  `blowAction = 3`, `scale = sf`, `opacity = 1.0`. animateOneFrame then calls resetActor, which sets a new location,
  `scale = 0.05·sf` and `blowFactor = 0.05`, but **does not set opacity**. That frame is therefore drawn with a tiny,
  **fully opaque** icon at the new spawn point, with the angle computed from the old actor's velocity.
  Brand-new actors from resetAnimation have opacity 0 (zero-filled) until their first moveActor.
  If you want to reproduce this, keep opacity at 1.0 for that frame. It is barely visible at 5% size.
- **U3 – bounds usage:** the floor is the absolute line y = halfH. It ignores `bounds.origin.y` and has no ceiling, so
  icons can leave the top of the screen and come back down. Spawning also ignores the origin. In practice the
  origin is (0,0), so only the right-wall formula (U4) is odd.
- **U4 – right wall formula:** the limit is computed as `(bounds.w - bounds.origin.x) - halfW` instead of
  `origin.x + w - halfW`. The two are the same when origin.x = 0.
- **U5 – collision size:** halfW and halfH use `image.size * _scaleFactor`, not the actor's current scale, so the
  bounce box stays the same while the icon grows or shrinks. With the defaults (128 px icon, sf 0.6), halfH = 38.4.
- **U6 – spawn height:** y = fmod(rnd, h−70) + 80 is in [80, h+10), so an icon can spawn up to 10 px above the
  top edge, centre included. It falls from rest, and because bounces lose no energy it keeps returning to
  about its spawn height. Bounces happen on the first frame where y < halfH, so there is no clamping and the icon
  can dip slightly below the floor line (up to |vy| px) for one frame.
- **U7 – energy:** gravity is skipped on the bounce frame and the bounce frame's position used the old (negative)
  velocity. Apex heights stay roughly constant but can drift by a pixel or so from bounce to bounce.
  This is not damped, so do not add damping.
- **U8:** `_lifeExpectancy == 0` would cause an integer divide-by-zero in resetActor. `_icons.count == 0` gives a nil
  image. In that case the i386 nil-message return for `[nil size]` puts 0 in eax, and edx is not guaranteed, so
  halfH is undefined. Irrelevant if icons always exist.
- **U9:** vx is an integer from −4 to +4 and can be 0, which gives a purely vertical bouncer.
  `velocity.y` after reset is exactly 0.
- Time unit: everything is per `animateOneFrame` call. The frame rate (AnimationSpeed) is set by the host view.
