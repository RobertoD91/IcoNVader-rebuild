/*
 * Game Of Life — GameOfLifeBehavior + GameOfLifeActor + GameOfLifeMatrix + GameOfLifeMatrixFreeze
 * Il gioco della vita di Conway (B3/S23, bordi morti) su una griglia di icone:
 * le nascite compaiono crescendo, le morti si gonfiano e svaniscono.
 * Se il gioco si spegne, si blocca o ripete uno degli ultimi 10 stati, si ricomincia.
 */
(function (IV) {
  'use strict';
  const { Actor, Behavior, random } = IV;

  const DEATH = 0;
  const BIRTH = 1;
  const THINK = 2;
  const FREEZE_QUEUE_LENGTH = 10;
  const GUTTER = 4;

  /** Passi di 0,05 calcolati in float32 come nell'originale (19 fotogrammi di crescita). */
  const f32 = Math.fround;

  class GameOfLifeActor extends Actor {
    constructor() {
      super();
      this.column = 0;
      this.row = 0;
      this.timeToLive = 0;
      this.blowFactor = 0;
    }
  }

  class GameOfLifeMatrix {
    constructor(columns, rows) {
      this.numberOfColumns = columns;
      this.numberOfRows = rows;
      this.data = new Array(columns * rows).fill(null);
    }

    actorAt(c, r) {
      if (c < 0 || r < 0 || c >= this.numberOfColumns || r >= this.numberOfRows) return null;
      return this.data[r * this.numberOfColumns + c];
    }

    setActor(a, c, r) {
      if (c < 0 || r < 0 || c >= this.numberOfColumns || r >= this.numberOfRows) return;
      this.data[r * this.numberOfColumns + c] = a;
    }

    insertActor(a) { this.setActor(a, a.column, a.row); }
    removeActor(a) { this.setActor(null, a.column, a.row); }
    reset() { this.data.fill(null); }

    /** GameOfLifeMatrixFreeze: istantanea delle celle vive (indici lineari in ordine). */
    freeze() {
      const out = [];
      this.data.forEach((a, i) => { if (a) out.push(i); });
      return out.join(',');
    }
  }

  function remove(list, item) {
    const i = list.indexOf(item);
    if (i >= 0) list.splice(i, 1);
  }

  class GameOfLifeBehavior extends Behavior {
    static get identifier() { return 'GameOfLife'; }
    static get displayName() { return 'Game Of Life'; }

    constructor(...args) {
      super(...args);
      this.bornActors = [];
      this.deadActors = [];
      this.matrixFreezeQueue = [];
      this.gamePhase = BIRTH;
      this.delay = 0;
      this.resetGameFlag = false;
      this.buildGrid();
    }

    /**
     * L'originale calcolava la griglia solo all'avvio; qui la si ricostruisce anche
     * quando la finestra cambia dimensione.
     */
    setBounds(bounds) {
      this.bounds = { ...bounds };
      this.buildGrid();
    }

    buildGrid() {
      const s = this.scaleFactor * 128;
      const extentFor = (limit) => {
        let n = 0;
        let ext = 0;
        let prev = 0;
        while (limit > ext) {
          prev = ext;
          n += 1;
          ext = n * s + (n - 1) * GUTTER;
        }
        return [Math.max(0, n - 1), prev];
      };
      const [cols, gridW] = extentFor(this.bounds.width);
      const [rows, gridH] = extentFor(this.bounds.height);
      this.gridRect = {
        x: Math.round((this.bounds.width - gridW) * 0.5),
        y: Math.round((this.bounds.height - gridH) * 0.5),
        width: gridW,
        height: gridH,
      };
      this.matrix = new GameOfLifeMatrix(cols, rows);
      this.resetGame();
    }

    spawnActorAt(col, row) {
      const a = new GameOfLifeActor();
      const sf = this.scaleFactor;
      const s = sf * 128;
      a.column = col;
      a.row = row;
      a.location = {
        x: this.gridRect.x + s * 0.5 + col * (s + GUTTER),
        y: this.gridRect.y + s * 0.5 + row * (s + GUTTER), // la riga 0 è in basso
      };
      a.image = this.icons.length ? this.icons[random() % this.icons.length] : null;
      a.scale = { x: sf * 0.05, y: sf * 0.05 };
      a.opacity = 1;
      a.timeToLive = random() % Math.max(1, Math.trunc(this.lifeExpectancy / 100));
      return a;
    }

    resetGame() {
      this.actors = [];
      this.bornActors = [];
      this.deadActors = [];
      this.matrixFreezeQueue = [];
      this.matrix.reset();
      for (let row = 0; row < this.matrix.numberOfRows; row++) {
        for (let col = 0; col < this.matrix.numberOfColumns; col++) {
          if (random() % 100 < this.density) this.bornActors.push(this.spawnActorAt(col, row));
        }
      }
      this.gamePhase = BIRTH;
      this.resetGameFlag = false;
    }

    animateOneFrame() {
      switch (this.gamePhase) {
        case BIRTH: this.birthPhase(); break;
        case THINK: this.thinkPhase(); break;
        case DEATH: this.deathPhase(); break;
        default: break;
      }
    }

    birthPhase() {
      if (this.bornActors.length === 0) {
        this.delay = Math.max(1, Math.trunc(this.lifeExpectancy / 50));
        this.gamePhase = THINK;
        return;
      }
      let changed = false;
      for (const a of this.bornActors.slice()) {
        if (a.timeToLive !== 0) {
          a.timeToLive -= 1;
          continue;
        }
        if (a.blowFactor === 0) {
          a.blowFactor = f32(0.05);
          this.actors.push(a); // diventa visibile qui
        }
        a.blowFactor = f32(a.blowFactor + 0.05);
        a.scale = { x: a.blowFactor * this.scaleFactor, y: a.blowFactor * this.scaleFactor };
        a.opacity = a.blowFactor;
        if (a.blowFactor > 1) {
          this.matrix.insertActor(a);
          remove(this.bornActors, a);
        }
        changed = true;
      }
      // Nell'originale si ordina la lista delle nascite, non quella disegnata
      if (changed) this.bornActors.sort((x, y) => x.compareDepth(y));
    }

    thinkPhase() {
      this.delay -= 1;
      if (this.delay !== 0) return;

      const freeze = this.matrix.freeze();
      if (this.matrixFreezeQueue.includes(freeze)) {
        this.killAll();
        return;
      }
      this.matrixFreezeQueue.push(freeze);
      if (this.matrixFreezeQueue.length > FREEZE_QUEUE_LENGTH) this.matrixFreezeQueue.shift();

      const m = this.matrix;
      const deathTtl = Math.max(1, Math.trunc(this.lifeExpectancy / 20));
      for (let row = 0; row < m.numberOfRows; row++) {
        for (let col = 0; col < m.numberOfColumns; col++) {
          let n = 0;
          for (let dc = -1; dc <= 1; dc++) {
            for (let dr = -1; dr <= 1; dr++) {
              if ((dc || dr) && m.actorAt(col + dc, row + dr)) n++;
            }
          }
          const cell = m.actorAt(col, row);
          if (cell) {
            if (n !== 2 && n !== 3) {
              this.deadActors.push(cell);
              cell.blowFactor = 0;
              cell.timeToLive = random() % deathTtl;
            }
          } else if (n === 3) {
            this.bornActors.push(this.spawnActorAt(col, row));
          }
        }
      }
      if (this.bornActors.length === 0 && this.deadActors.length === 0) {
        this.killAll();
        return;
      }
      this.gamePhase = DEATH;
    }

    /** Stallo o ciclo: tutte le icone esplodono e si riparte con una nuova scacchiera. */
    killAll() {
      this.resetGameFlag = true;
      const deathTtl = Math.max(1, Math.trunc(this.lifeExpectancy / 20));
      this.deadActors.push(...this.actors);
      for (const a of this.deadActors) {
        a.blowFactor = 0;
        a.timeToLive = random() % deathTtl;
      }
      this.gamePhase = DEATH;
    }

    deathPhase() {
      if (this.deadActors.length === 0) {
        if (this.actors.length === 0 && this.bornActors.length === 0) this.resetGameFlag = true;
        if (this.resetGameFlag) {
          this.resetGame();
          return;
        }
        this.gamePhase = BIRTH;
        return;
      }
      let changed = false;
      for (const a of this.deadActors.slice()) {
        if (a.timeToLive !== 0) {
          a.timeToLive -= 1;
          continue;
        }
        a.blowFactor = f32(a.blowFactor + 0.05);
        const sc = (a.blowFactor * 1.5 + 1) * this.scaleFactor; // fino a circa 2,5×
        a.scale = { x: sc, y: sc };
        a.opacity = 1 - a.blowFactor;
        if (a.blowFactor > 1) {
          this.matrix.removeActor(a);
          remove(this.deadActors, a);
          remove(this.actors, a);
        }
        changed = true;
      }
      if (changed) this.deadActors.sort((x, y) => x.compareDepth(y));
    }
  }

  IV.registerBehavior(GameOfLifeBehavior);
})(window.IcoNVader);
