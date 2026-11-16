# Hypnosis behavior (HypnosisBehavior + HypnosisActor)

Identifier `"Hypnosis"`, localized name key `"Hypnosis"`.
Sources: `cls/HypnosisBehavior.s`, `cls/HypnosisActor.s` (base: `cls/IVActor.s`, `cls/IVBehavior.s`).

## 1. What it looks like

Concentric rings of icons centred on the screen (7 rings on screens up to 1792 px on the long side,
more on bigger ones), each ring packed edge-to-edge with icons whose tops point radially outward.
The rings rotate rigidly about the screen centre in alternating directions (innermost ring
counter-clockwise, next clockwise, ...), outer rings faster in angular speed (0.2, 0.4, ... up to
1.6 deg/frame), giving a hypnotic counter-rotating "target" pattern. Nothing ever fades, respawns or
changes image; Density, LifeExpectancy and ScaleFactor are all ignored – the layout depends only on the
screen size.

## 2. Data

```
HypnosisActor : IVActor     // IVActor: location{x,y}, angle(deg), scale{x,y}, opacity, image, identifier
  velocity   : float        // +0x28  deg per frame (always > 0)
  waveAction : int          // +0x2c  0 = angle increases (CCW), 1 = angle decreases (CW), other = frozen
  waveAngle  : float        // +0x30  polar angle on the ring, degrees
  waveRadius : float        // +0x34  ring radius, px

HypnosisBehavior : IVBehavior
  icons : NSArray           // +0x24
```

## 3. Pseudocode

`pick(icons)` = `icons.count ? icons[random() % icons.count] : nil` (unsigned modulo, libc random()).

```
initWithBounds(bounds, icons, density, lifeExpectancy, scaleFactor):
    super.init(...)                // stores bounds/density/lifeExpectancy/scaleFactor, actors = []
    self.icons = icons
    self.resetAnimation()

resetAnimation():
    maxDim  = max(bounds.width, bounds.height)
    spacing = maxDim / 14.0
    if spacing > 128.0:                         // i.e. maxDim > 1792
        ringCount = (int)(maxDim * (1/256.0) + 1.0)   // truncation
        spacing   = 128.0
        iconScale = 1.0
    else:
        iconScale = spacing * (1/128.0)         // so drawn icon size == spacing for 128px icons
        ringCount = 7
    actors.removeAll()
    flag = true
    for i in 0 ..< ringCount:
        radius   = spacing + (spacing + 10.0) * i
        velocity = (float)((min(i, 7) + 1) * 0.2)            // 0.2,0.4,...,1.6, capped at 1.6
        n        = (int)( (float)(radius * 2*PI) / spacing ) // truncation; how many icons fit
        step     = (float)( 360 / n )                        // INTEGER division (C int), then to float
        a = 0.0
        do:
            act = HypnosisActor.actor()
            act.image      = pick(icons)
            act.waveRadius = radius
            act.waveAngle  = a
            act.opacity    = 1.0
            act.velocity   = velocity
            act.scale      = (iconScale, iconScale)
            act.waveAction = flag ? 0 : 1        // ring 0 → 0, ring 1 → 1, ring 2 → 0, ...
            actors.add(act)
            a += step
        while a < 360.0
        flag = !flag

animateOneFrame():
    for act in actors: self.moveActor(act)
    actors.sortUsingSelector(compareDepth:)     // IVActor.compareDepth (not overridden)

moveActor(act):
    if act.waveAction == 0:
        act.waveAngle = (float) fmod(act.waveAngle + act.velocity, 360.0)
    else if act.waveAction == 1:
        act.waveAngle = (float) fmod(act.waveAngle - act.velocity, 360.0)   // C fmod: result keeps
                                                                            // sign → goes into (-360,0]
    // (any other waveAction: angle unchanged – never happens)
    cx = bounds.x + bounds.width  * 0.5
    cy = bounds.y + bounds.height * 0.5
    th = act.waveAngle * PI / 180
    act.location = (cx + act.waveRadius * cos(th),
                    cy + act.waveRadius * sin(th))           // y-up
    act.angle = act.waveAngle - 90.0                         // icon's top points away from centre
```

Note: the actor's position/angle are only set by `moveActor`, so before the first `animateOneFrame`
all actors sit at (0,0) with angle 0 (irrelevant since a frame is animated before each render).

Because `step = floor(360/n)` the loop usually creates *more* than `n` icons and the last icon lands
a few degrees short of 360, partly overlapping the first one (e.g. step 27 → 14 icons at 0..351;
step 7 → 52 icons, last at 357). This overlap is a genuine artefact of the original; reproduce it.

Worked layouts (ScaleFactor irrelevant):

| screen | spacing / iconScale | ring: radius, n, step, icons, vel, dir |
|---|---|---|
| 1440x900 | 102.857 / 0.8036, 7 rings | r0 102.86,6,60,6,0.2,CCW · r1 215.71,13,27,14,0.4,CW · r2 328.57,20,18,20,0.6,CCW · r3 441.43,26,13,28,0.8,CW · r4 554.29,33,10,36,1.0,CCW · r5 667.14,40,9,40,1.2,CW · r6 780.0,47,7,52,1.4,CCW |
| 1920x1080 | 128 / 1.0, 8 rings | 128/6/60/6 · 266/13/27/14 · 404/19/18/20 · 542/26/13/28 · 680/33/10/36 · 818/40/9/40 · 956/46/7/52 · 1094/53/6/60 (vel 1.6, CW) |
| 800x600 | 57.143 / 0.4464, 7 rings | 57.14/6/60/6 · 124.29/13/27/14 · 191.43/21/17/22 · 258.57/28/12/30 · 325.71/35/10/36 · 392.86/43/8/45 · 460/50/7/52 |

(Computed with float32 emulation; tiny float differences can change `n` only at exact boundaries.)

### Depth order — IVActor.compareDepth(other) (inherited)

```
compareDepth(other):
    if self.opacity == other.opacity:
        if self.identifier == other.identifier: return 0
        return (self.identifier < other.identifier) ? +1 : -1   // unsigned compare
    return (other.opacity > self.opacity) ? +1 : -1             // higher opacity sorts first
```

All Hypnosis opacities are 1.0, so the order is simply **descending identifier** (identifier = global
creation counter from `-[IVActor init]`). Renderer draws index 0 first, so the **last-created actors
are drawn first (bottom)** and the first-created are on top: outer rings are underneath inner rings,
and within a ring the icon created at angle 0 is on top of later ones (this decides which icon wins
in the overlapping last/first pair). The order never changes, so in JS: create actors in the order
above and draw the array in reverse creation order.

### Rendering (QuartzRenderer, for reference)

Per actor: translate(location) → rotateByDegrees(angle) (CCW in y-up) → translate(-w*sx/2, -h*sy/2)
→ scale(sx, sy) → draw image at origin with fraction = opacity. In a y-down canvas:
`ctx.translate(x, H - y); ctx.rotate(-angle * PI/180); ctx.scale(sx, sy); ctx.drawImage(img, -w/2, -h/2)`.
With `angle = waveAngle - 90`: icon at the top of a ring (waveAngle 90) is upright, at the right
(waveAngle 0) it is turned 90° clockwise, i.e. icon "up" always points outward.

## 4. Uncertainties / notes

- All constants are read directly from code: 14, 128, 1/128 (0.0078125), 1/256 (0.00390625), 1.0, 10,
  0.2, cap index 7, 2π, 360 (integer), 360.0, 0.5, π/180, 90. No guesses.
- `n` could be 0 only if radius*2π < spacing, impossible here (min n = 6), so no div-by-zero guard
  is needed; add one anyway in JS for safety.
- `maxss` with NaN bounds is irrelevant.
- `density`, `lifeExpectancy`, `scaleFactor` are unused by this behavior (verified: no reads of
  +0x14/+0x18/+0x1c in HypnosisBehavior).
- Images are chosen once in `resetAnimation` (called from init and again from `-[IVBehavior setBounds:]`
  on resize); they never change while running.
- NSMutableArray `sortUsingSelector:` stability doesn't matter: identifiers are unique, so the order is
  total.
