/*
 * Hypnosis — HypnosisBehavior + HypnosisActor
 * Anelli concentrici di icone (con la cima rivolta verso l'esterno) che ruotano attorno
 * al centro dello schermo in direzioni alterne, più velocemente verso l'esterno.
 */
(function (IV) {
  'use strict';
  const { Actor, Behavior, random, DEG } = IV;

  class HypnosisActor extends Actor {
    constructor() {
      super();
      this.velocity = 0;   // gradi per fotogramma
      this.waveAction = 0; // 0 = antiorario, 1 = orario
      this.waveAngle = 0;  // posizione angolare sull'anello (gradi)
      this.waveRadius = 0; // raggio dell'anello (px)
    }
  }

  class HypnosisBehavior extends Behavior {
    static get identifier() { return 'Hypnosis'; }
    static get displayName() { return 'Hypnosis'; }

    constructor(...args) {
      super(...args);
      this.resetAnimation();
    }

    resetAnimation() {
      const maxDim = Math.max(this.bounds.width, this.bounds.height);
      let spacing = maxDim / 14;
      let ringCount;
      let iconScale;
      if (spacing > 128) {
        ringCount = Math.trunc(maxDim * (1 / 256) + 1);
        spacing = 128;
        iconScale = 1;
      } else {
        iconScale = spacing * (1 / 128);
        ringCount = 7;
      }
      this.actors = [];
      let counterClockwise = true;
      for (let i = 0; i < ringCount; i++) {
        const radius = spacing + (spacing + 10) * i;
        const velocity = (Math.min(i, 7) + 1) * 0.2;
        const n = Math.max(1, Math.trunc((radius * 2 * Math.PI) / spacing));
        const step = Math.trunc(360 / n); // divisione intera come nell'originale
        let a = 0;
        do {
          const act = new HypnosisActor();
          act.image = this.icons.length ? this.icons[random() % this.icons.length] : null;
          act.waveRadius = radius;
          act.waveAngle = a;
          act.opacity = 1;
          act.velocity = velocity;
          act.scale = { x: iconScale, y: iconScale };
          act.waveAction = counterClockwise ? 0 : 1;
          this.actors.push(act);
          a += step;
        } while (a < 360);
        counterClockwise = !counterClockwise;
      }
    }

    animateOneFrame() {
      for (const act of this.actors) this.moveActor(act);
      this.sortActorsByDepth();
    }

    moveActor(act) {
      if (act.waveAction === 0) {
        act.waveAngle = (act.waveAngle + act.velocity) % 360;
      } else if (act.waveAction === 1) {
        act.waveAngle = (act.waveAngle - act.velocity) % 360;
      }
      const cx = this.bounds.x + this.bounds.width * 0.5;
      const cy = this.bounds.y + this.bounds.height * 0.5;
      const th = act.waveAngle * DEG;
      act.location = { x: cx + act.waveRadius * Math.cos(th), y: cy + act.waveRadius * Math.sin(th) };
      act.angle = act.waveAngle - 90;
    }
  }

  IV.registerBehavior(HypnosisBehavior);
})(window.IcoNVader);
