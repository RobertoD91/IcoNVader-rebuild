/*
 * DNA — DNABehavior + DNAHelix + DNAActor
 * Una fila di doppie eliche verticali fatte di icone che ruotano sul proprio asse
 * e scorrono in verticale, alternando la direzione da un'elica all'altra.
 */
(function (IV) {
  'use strict';
  const { Actor, Behavior, random, DEG } = IV;

  const RUNGS = 20;

  class DNAActor extends Actor {
    constructor() {
      super();
      this.heightOffset = 0;
      this.angleOffset = 0;
    }

    /** Prima le icone piccole (lontane), a parità di scala quelle più in alto. */
    compareDepth(other) {
      if (this.scale.x === other.scale.x) {
        if (this.location.y === other.location.y) return 0;
        return other.location.y > this.location.y ? 1 : -1;
      }
      return this.scale.x > other.scale.x ? 1 : -1;
    }
  }

  function pick(icons) {
    return icons.length ? icons[random() % icons.length] : null;
  }

  /** Intersezione come NSIntersectsRect (i bordi a contatto non contano). */
  function intersects(a, b) {
    if (a.width <= 0 || a.height <= 0 || b.width <= 0 || b.height <= 0) return false;
    return !(a.x + a.width <= b.x || b.x + b.width <= a.x ||
             a.y + a.height <= b.y || b.y + b.height <= a.y);
  }

  class DNAHelix {
    constructor(icons, location, velocity, scaleFactor) {
      this.scale = scaleFactor * 0.25 + 0.25; // -[DNAHelix setScale:]
      this.actors = [];
      let angleOffset = 0;
      for (let i = 0; i < RUNGS; i++) {
        const h = i * (128 * this.scale);
        for (const off of [angleOffset, (angleOffset + 180) % 360]) {
          const a = new DNAActor();
          a.image = pick(icons);
          a.angleOffset = off;
          a.heightOffset = h;
          a.opacity = 1;
          a.scale = { x: this.scale, y: this.scale };
          this.actors.push(a);
        }
        angleOffset += 30; // 30° di torsione per gradino
      }
      this.location = { ...location };
      this.velocity = velocity;
      this.angle = 0;
      this.hasLived = false;
      this.icons = icons;
    }

    moveInsideBounds(bounds) {
      this.location.y += this.velocity;
      this.angle = (1 + this.angle) % 360;
      const radius = 512 * this.scale;
      for (const a of this.actors) {
        const theta = (this.angle + a.angleOffset) * DEG;
        a.location = { x: this.location.x + Math.cos(theta) * radius, y: this.location.y + a.heightOffset };
        const k = (Math.sin(theta) * 0.5 + 1) * this.scale;
        a.scale = { x: k, y: k };
      }
      const rect = {
        x: this.location.x - 0.5 * radius,
        y: this.location.y,
        width: radius,
        height: 128 * this.scale * RUNGS,
      };
      if (!this.hasLived) {
        if (intersects(rect, bounds)) this.hasLived = true;
      } else if (!intersects(rect, bounds)) {
        this.resetWithBounds(bounds);
      }
    }

    /** L'elica uscita dallo schermo rientra dal lato opposto con nuova velocità e nuove icone. */
    resetWithBounds(bounds) {
      const mag = (random() % 3) + 1;
      this.velocity = this.velocity < 0 ? -mag : mag;
      for (const a of this.actors) a.image = pick(this.icons);
      if (this.velocity > 0) {
        this.location.y = -128 * this.scale * RUNGS;
      } else {
        this.location.y = bounds.y + bounds.height - 10;
      }
      this.hasLived = false;
      this.moveInsideBounds(bounds);
    }
  }

  class DNABehavior extends Behavior {
    static get identifier() { return 'DNA'; }
    static get displayName() { return 'DNA'; }

    constructor(...args) {
      super(...args);
      this.helixes = [];
      this.resetAnimation();
    }

    resetAnimation() {
      const t = this.scaleFactor * 0.25 + 0.25;
      const spacing = t * 1024 + t * 256 + 10;
      const W = this.bounds.width + 10;
      const count = Math.ceil(W / spacing);
      const leftover = W - count * spacing;
      let x = (spacing + leftover) * 0.5;
      this.helixes = [];
      this.actors = [];
      let dir = -1;
      for (let i = 0; i < count; i++) {
        const v = ((random() % 3) + 1) * dir;
        const helix = new DNAHelix(this.icons, { x, y: 0 }, v, this.scaleFactor);
        this.helixes.push(helix);
        this.actors.push(...helix.actors);
        dir = -dir;
        x += spacing;
      }
    }

    animateOneFrame() {
      for (const h of this.helixes) h.moveInsideBounds(this.bounds);
      this.sortActorsByDepth();
    }
  }

  IV.registerBehavior(DNABehavior);
})(window.IcoNVader);
