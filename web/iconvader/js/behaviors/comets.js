/*
 * Comets — CometsBehavior + CometsActor
 * Le icone entrano dai bordi dello schermo in linea retta e, durante la loro breve vita,
 * rimpiccioliscono e svaniscono; poi rinascono da un bordo a caso.
 */
(function (IV) {
  'use strict';
  const { Actor, Behavior, random } = IV;

  class CometsActor extends Actor {
    constructor() {
      super();
      this.velocity = { x: 0, y: 0 };
      this.timeToLive = 0;
      this.blowFactor = 0;
      this.hasLived = false;
    }
  }

  /** NSPointInRect: rettangolo semiaperto. */
  function pointInRect(p, r) {
    return p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height;
  }

  /** Numero di attori, comune a Comets e Jumpers: larghezza/128 × (densità+3)/10. */
  function actorCount(bounds, density) {
    return Math.trunc(bounds.width * 0.0078125 * ((density + 3) / 10));
  }

  class CometsBehavior extends Behavior {
    static get identifier() { return 'Comets'; }
    static get displayName() { return 'Comets'; }

    constructor(...args) {
      super(...args);
      this.resetAnimation();
    }

    resetAnimation() {
      const n = actorCount(this.bounds, this.density);
      this.actors = [];
      for (let i = 0; i < n; i++) {
        const a = new CometsActor();
        this.resetActor(a);
        this.actors.push(a);
      }
    }

    resetActor(a) {
      const sf = this.scaleFactor;
      const W = this.bounds.width;
      const H = this.bounds.height;
      let x, y, dir;
      switch (random() % 4) {
        case 0: // bordo sinistro, verso destra
          x = -128 * sf;
          y = random() % H;
          dir = { x: 1, y: random() % 2 }; // 0 o 1: mai verso il basso (come nell'originale)
          break;
        case 1: // bordo superiore, verso il basso
          x = random() % W;
          y = H + sf * 128;
          dir = { x: random() % 2, y: -1 };
          break;
        case 2: // bordo destro, verso sinistra
          x = W + sf * 128;
          y = random() % H;
          dir = { x: -1, y: random() % 2 };
          break;
        default: // bordo inferiore, verso l'alto
          x = random() % W;
          y = -128 * sf;
          dir = { x: random() % 2, y: 1 };
          break;
      }
      a.image = this.icons.length ? this.icons[random() % this.icons.length] : null;
      a.angle = 0;
      a.scale = { x: sf, y: sf };
      a.blowFactor = 1;
      a.opacity = 1;
      const r1 = random();
      const r2 = random();
      a.velocity = { x: (r2 % 10 + 3) * dir.x, y: (r1 % 10 + 3) * dir.y };
      a.timeToLive = Math.trunc((random() % Math.max(1, this.lifeExpectancy)) / 5);
      a.location = { x, y };
      a.hasLived = false;
    }

    moveActor(a) {
      const blow = a.blowFactor + (-1 / a.timeToLive);
      a.blowFactor = blow;
      a.location = { x: a.location.x + a.velocity.x, y: a.location.y + a.velocity.y };
      a.scale = { x: blow * this.scaleFactor, y: blow * this.scaleFactor };
      a.opacity = blow;
      if (pointInRect(a.location, this.bounds)) a.hasLived = true;
    }

    animateOneFrame() {
      for (const a of this.actors) {
        this.moveActor(a);
        if (a.blowFactor <= 0.05) {
          this.resetActor(a);
        } else if (a.hasLived && !pointInRect(a.location, this.bounds)) {
          this.resetActor(a);
        }
      }
      this.sortActorsByDepth();
    }
  }

  IV.registerBehavior(CometsBehavior);
  IV.actorCount = actorCount;
})(window.IcoNVader);
