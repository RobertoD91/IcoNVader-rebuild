/*
 * Fireworks — FireworksBehavior + FireworksActor
 * Le icone partono dal fondo come razzi, rallentano per gravità, si gonfiano in cima
 * e scoppiano in 8 copie che volano nelle direzioni della rosa dei venti svanendo.
 */
(function (IV) {
  'use strict';
  const { Actor, Behavior, random } = IV;

  class FireworksActor extends Actor {
    constructor() {
      super();
      this.velocity = { x: 0, y: 0 };
      this.maxLife = 0;
      this.currentLife = 0;
    }

    /** Ordinamento invertito rispetto a IVActor: le più opache sopra, a parità le più vecchie sopra. */
    compareDepth(other) {
      if (this.opacity === other.opacity) {
        if (this.identifier === other.identifier) return 0;
        return this.identifier < other.identifier ? 1 : -1;
      }
      return this.opacity > other.opacity ? 1 : -1;
    }
  }

  // Direzioni delle 8 scintille: N, NE, E, SE, S, SO, O, NO (diagonali non normalizzate)
  const SPARK_DIRECTIONS = [[0, 1], [1, 1], [1, 0], [1, -1], [0, -1], [-1, -1], [-1, 0], [-1, 1]];

  function remove(list, item) {
    const i = list.indexOf(item);
    if (i >= 0) list.splice(i, 1);
  }

  class FireworksBehavior extends Behavior {
    static get identifier() { return 'Fireworks'; }
    static get displayName() { return 'Fireworks'; }

    constructor(...args) {
      super(...args);
      this.fireworks = [];
      this.sparks = [];
      this.maxSpeed = 0;
      this.resetAnimation();
    }

    /** Calcola la velocità di lancio massima perché i razzi non escano dall'alto. */
    resetAnimation() {
      const H = this.bounds.height;
      let k = 10;
      let apex = 105;
      while (H > apex) {
        k += 1;
        const n = 2 * k;
        apex = n * (n - (n - 1) * 0.5) * 0.5;
      }
      this.maxSpeed = Math.max(1, k - 11);
      this.sparks = [];
      this.fireworks = [];
      this.actors = [];
    }

    animateOneFrame() {
      if (this.sparks.length <= 399) {
        if (random() % (101 - this.density) === 0) {
          const a = new FireworksActor();
          this.resetActor(a);
          this.fireworks.push(a);
          this.actors.push(a);
        }
      }
      for (const a of this.fireworks.slice()) this.moveActor(a);
      for (const p of this.sparks.slice()) this.moveSpark(p);
      this.sortActorsByDepth();
    }

    /** Lancio di un razzo. */
    resetActor(a) {
      const sf = this.scaleFactor;
      const s = 128 * sf;
      a.image = this.icons.length ? this.icons[random() % this.icons.length] : null;
      a.angle = 0;
      a.scale = { x: sf, y: sf };
      a.opacity = 1;
      const vy = random() % this.maxSpeed + 10;
      const vx = random() % 9 - 4;
      a.velocity = { x: vx, y: vy };
      const span = Math.max(1, this.bounds.width - 2 * s);
      a.location = { x: (random() % span) + s, y: -s };
      a.maxLife = random() % 10;
      a.currentLife = a.maxLife;
    }

    moveActor(a) {
      const vel = a.velocity;
      if (!(vel.y > 0)) {
        const cl = a.currentLife;
        if (cl === 0) {
          this.spawnSparks(a.location, a.image);
          remove(this.fireworks, a);
          remove(this.actors, a);
          return;
        }
        const f = (cl / a.maxLife) * -2 + 3; // si gonfia fino a quasi 3×
        a.scale = { x: f * this.scaleFactor, y: f * this.scaleFactor };
        a.currentLife = cl - 1;
      }
      a.location = { x: a.location.x + vel.x, y: a.location.y + vel.y };
      a.velocity = { x: vel.x, y: vel.y - 0.5 };
    }

    spawnSparks(loc, img) {
      const m = Math.max(1, Math.trunc((this.lifeExpectancy * 300) / 5000));
      const life = random() % m + 10; // stessa durata per le 8 scintille
      for (const [dx, dy] of SPARK_DIRECTIONS) {
        const p = new FireworksActor();
        const speed = random() % 10 + 1;
        p.image = img;
        p.angle = 0;
        p.scale = { x: this.scaleFactor, y: this.scaleFactor };
        p.opacity = 1;
        p.location = { ...loc };
        p.maxLife = life;
        p.currentLife = life;
        p.velocity = { x: dx * speed, y: dy * speed };
        this.sparks.push(p);
        this.actors.push(p);
      }
    }

    moveSpark(p) {
      const cl = p.currentLife;
      if (cl === 0) {
        remove(this.sparks, p);
        remove(this.actors, p);
        return;
      }
      const f = cl / p.maxLife;
      p.opacity = f;
      p.scale = { x: f * this.scaleFactor, y: f * this.scaleFactor };
      p.currentLife = cl - 1;
      p.location = { x: p.location.x + p.velocity.x, y: p.location.y + p.velocity.y };
    }
  }

  IV.registerBehavior(FireworksBehavior);
})(window.IcoNVader);
