/*
 * Jumpers — JumpersBehavior + JumpersActor
 * Le icone compaiono crescendo, rimbalzano sul fondo dello schermo con gravità costante
 * (a volte con una capriola), poi "esplodono" ingrandendosi e svanendo, e rinascono altrove.
 */
(function (IV) {
  'use strict';
  const { Actor, Behavior, random } = IV;

  const APPEARING = 0;
  const ALIVE = 1;
  const EXPLODING = 2;
  const DEAD = 3;

  class JumpersActor extends Actor {
    constructor() {
      super();
      this.velocity = { x: 0, y: 0 };
      this.timeToLive = 0;
      this.rotationAction = 0;        // 0 nessuna, 1 capriola in avanti, 2 all'indietro
      this.rotationVelocityRange = 0;
      this.blowAction = APPEARING;
      this.blowFactor = 0;
    }
  }

  class JumpersBehavior extends Behavior {
    static get identifier() { return 'Jumpers'; }
    static get displayName() { return 'Jumpers'; }

    constructor(...args) {
      super(...args);
      this.resetAnimation();
    }

    resetAnimation() {
      const n = IV.actorCount(this.bounds, this.density);
      this.actors = [];
      for (let i = 0; i < n; i++) {
        const a = new JumpersActor();
        this.resetActor(a);
        this.actors.push(a);
      }
    }

    /** Come nell'originale, non azzera opacità, angolo né la capriola in corso. */
    resetActor(a) {
      const b = this.bounds;
      const s0 = this.scaleFactor * 0.05;
      a.image = this.icons.length ? this.icons[random() % this.icons.length] : null;
      const y = (random() % (b.height - 70)) + 80;
      const x = (random() % (b.width - 40)) + 10;
      a.location = { x, y };
      a.scale = { x: s0, y: s0 };
      a.velocity = { x: (random() % 9) - 4, y: 0 };
      a.timeToLive = random() % Math.max(1, this.lifeExpectancy);
      a.blowAction = APPEARING;
      a.blowFactor = 0.05;
    }

    moveActor(a) {
      const B = this.bounds;
      const sf = this.scaleFactor;
      const v = a.velocity;
      const x = a.location.x + v.x;
      const y = a.location.y + v.y;
      a.location = { x, y };

      const img = a.image;
      const iw = img ? img.naturalWidth || img.width : 128;
      const ih = img ? img.naturalHeight || img.height : 128;
      const halfW = 0.5 * (iw * sf);
      const halfH = (sf * ih) * 0.5;

      // Pavimento e gravità
      let vx = v.x;
      let vy;
      if (halfH > y && v.y < 0) {
        vy = -v.y;
        if ((random() & 3) === 0) vx = -vx;
        a.rotationVelocityRange = Math.abs(vy / 1.3);
        a.rotationAction = random() % 3;
      } else {
        vy = v.y - 1;
      }

      // Pareti laterali (formula del bordo destro come nell'originale)
      if (x < B.x + halfW && vx < 0) {
        vx = -vx;
      } else if (x > (B.width - B.x) - halfW && vx > 0) {
        vx = -vx;
      }
      a.velocity = { x: vx, y: vy };

      // Macchina a stati: comparsa → vita → esplosione → morte
      let blow = a.blowFactor;
      switch (a.blowAction) {
        case APPEARING:
          blow += 0.05;
          if (blow > 1) { a.blowAction = ALIVE; blow = 0; }
          break;
        case ALIVE:
          blow += 1 / a.timeToLive;
          if (blow > 1) { a.blowAction = EXPLODING; blow = 0; }
          break;
        case EXPLODING:
          blow += 0.05;
          if (blow > 1) a.blowAction = DEAD;
          break;
        default:
          break;
      }
      a.blowFactor = blow;

      // Capriola attorno al punto più alto del salto
      const R = a.rotationVelocityRange;
      let angle = 0;
      if (!(R < Math.abs(vy)) && R > 0) {
        if (a.rotationAction === 1) angle = (1 - vy / R) * 180;
        else if (a.rotationAction === 2) angle = (vy / R + 1) * 180;
      }
      a.angle = angle;

      let s;
      if (a.blowAction === APPEARING) s = blow * sf;
      else if (a.blowAction === EXPLODING) s = (blow * 5 + 1) * sf;
      else s = sf;
      a.scale = { x: s, y: s };

      if (a.blowAction === APPEARING) a.opacity = blow;
      else if (a.blowAction === EXPLODING) a.opacity = 1 - blow;
      else a.opacity = 1;
    }

    animateOneFrame() {
      for (const a of this.actors) {
        this.moveActor(a);
        if (a.blowAction === DEAD) this.resetActor(a);
      }
      this.sortActorsByDepth();
    }
  }

  IV.registerBehavior(JumpersBehavior);
})(window.IcoNVader);
