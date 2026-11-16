/*
 * IcoNVader (ricostruzione web) — nucleo
 *
 * Riproduce le classi di base del salvaschermo originale (IcoNVader 3.0, Daedale 2004-2006),
 * ricavate dal binario i386: IVActor, IVBehavior, QuartzRenderer, IVScreenView, IVPreferences.
 * Le coordinate sono quelle di Cocoa (origine in basso a sinistra, y verso l'alto, angoli in gradi
 * in senso antiorario): la conversione verso il canvas avviene solo nel renderer.
 */
(function (global) {
  'use strict';

  // ---------------------------------------------------------------------------
  // Numeri casuali: libc random() e le macro inline di ScreenSaver.framework
  // ---------------------------------------------------------------------------
  const LONG_MAX = 2147483647;

  /** random() di libc: intero in [0, 2^31 - 1]. */
  function random() {
    return Math.floor(Math.random() * 2147483648);
  }

  /** SSRandomIntBetween(a, b) di ScreenSaverView.h. */
  function SSRandomIntBetween(a, b) {
    const range = b - a < 0 ? b - a - 1 : b - a + 1;
    const value = Math.trunc(range * (Math.fround(random()) / Math.fround(LONG_MAX)));
    return value === range ? a : a + value;
  }

  /** SSRandomFloatBetween(a, b) di ScreenSaverView.h. */
  function SSRandomFloatBetween(a, b) {
    return a + (b - a) * (random() / LONG_MAX);
  }

  const DEG = Math.PI / 180;

  // ---------------------------------------------------------------------------
  // IVActor
  // ---------------------------------------------------------------------------
  let identifierSeed = 0; // sIdentifierSeed nel binario

  class Actor {
    constructor() {
      this.identifier = identifierSeed++;
      this.location = { x: 0, y: 0 };
      this.angle = 0;            // gradi
      this.scale = { x: 0, y: 0 };
      this.opacity = 0;
      this.image = null;
      this.userInfo = {};
    }

    /**
     * -[IVActor compareDepth:] — ordine di disegno predefinito: prima gli attori più opachi,
     * a parità di opacità quelli con identificatore più alto.
     */
    compareDepth(other) {
      if (this.opacity === other.opacity) {
        if (this.identifier === other.identifier) return 0;
        return this.identifier < other.identifier ? 1 : -1;
      }
      return other.opacity > this.opacity ? 1 : -1;
    }
  }

  // ---------------------------------------------------------------------------
  // IVBehavior
  // ---------------------------------------------------------------------------
  class Behavior {
    /**
     * @param {{x:number,y:number,width:number,height:number}} bounds
     * @param {HTMLImageElement[]} icons
     * @param {number} density        0..100
     * @param {number} lifeExpectancy 100..5000 (fotogrammi)
     * @param {number} scaleFactor    0.1..1.0
     */
    constructor(bounds, icons, density, lifeExpectancy, scaleFactor) {
      this.bounds = { ...bounds };
      this.icons = icons;
      this.density = density;
      this.lifeExpectancy = lifeExpectancy;
      this.scaleFactor = scaleFactor;
      this.actors = [];
    }

    static get identifier() { return ''; }
    static get displayName() { return ''; }

    /** -[IVBehavior setBounds:] memorizza i nuovi limiti e riparte con resetAnimation. */
    setBounds(bounds) {
      this.bounds = { ...bounds };
      this.resetAnimation();
    }
    resetAnimation() {}
    animateOneFrame() {}

    /** Immagine casuale dal set (random() % count, come nel binario). */
    randomIcon() {
      return this.icons[random() % this.icons.length];
    }

    /** Ordina gli attori con compareDepth: (sortUsingSelector: dell'originale). */
    sortActorsByDepth() {
      this.actors.sort((a, b) => a.compareDepth(b));
    }
  }

  const behaviorRegistry = [];

  function registerBehavior(cls) {
    behaviorRegistry.push(cls);
  }

  // ---------------------------------------------------------------------------
  // Renderer (equivalente di QuartzRenderer / OpenGLRenderer)
  // ---------------------------------------------------------------------------
  class Renderer {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.backgroundColor = '#000000';
      this.dpr = 1;
      this.width = 0;
      this.height = 0;
    }

    setFrameSize(width, height) {
      this.dpr = global.devicePixelRatio || 1;
      this.width = width;
      this.height = height;
      this.canvas.width = Math.round(width * this.dpr);
      this.canvas.height = Math.round(height * this.dpr);
      this.canvas.style.width = width + 'px';
      this.canvas.style.height = height + 'px';
    }

    /**
     * Per ogni attore: trasla in location, ruota di angle, trasla di -size*scale/2,
     * scala di scale e disegna l'immagine con opacità (NSCompositeSourceOver).
     */
    renderActors(actors) {
      const ctx = this.ctx;
      const dpr = this.dpr;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.globalAlpha = 1;
      ctx.fillStyle = this.backgroundColor;
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      ctx.imageSmoothingQuality = 'high';

      for (const actor of actors) {
        const img = actor.image;
        if (!img || actor.opacity <= 0) continue;
        const w = img.naturalWidth || img.width;
        const h = img.naturalHeight || img.height;
        const sx = actor.scale.x;
        const sy = actor.scale.y;
        if (sx === 0 || sy === 0) continue;
        // Sistema Cocoa: y verso l'alto
        ctx.setTransform(dpr, 0, 0, -dpr, 0, this.height * dpr);
        ctx.translate(actor.location.x, actor.location.y);
        ctx.rotate(actor.angle * DEG);
        ctx.translate(-0.5 * w * sx, -0.5 * h * sy);
        ctx.scale(sx, sy);
        // L'immagine va disegnata dritta: si ribalta di nuovo l'asse y
        ctx.translate(0, h);
        ctx.scale(1, -1);
        ctx.globalAlpha = Math.max(0, Math.min(1, actor.opacity));
        ctx.drawImage(img, 0, 0, w, h);
      }
      ctx.globalAlpha = 1;
    }
  }

  // ---------------------------------------------------------------------------
  // Preferenze (IVPreferences + DefaultPreferences.plist)
  // ---------------------------------------------------------------------------
  const DEFAULT_PREFERENCES = Object.freeze({
    animationSpeed: 30,               // fotogrammi al secondo (10..60)
    density: 50,                      // "Invasion Level" (0..100)
    lifeExpectancy: 1200,             // "Life expectancy" (100..5000)
    scaleFactor: 0.6,                 // "Icons size" (0.1..1.0)
    randomBehavior: true,
    randomBehaviorChangeInterval: 300, // secondi; 0 = mai
    behavior: 'Comets',               // senza preferenza: il primo della lista
    iconSet: 'Christmas',
    backgroundColor: '#000000',       // ShadingColor (predefinito: nero)
    language: 'auto',                 // 'auto' = lingua del browser; altrimenti 'en', 'fr', 'it'
  });

  const PREF_LIMITS = Object.freeze({
    animationSpeed: [10, 60],
    density: [0, 100],
    lifeExpectancy: [100, 5000],
    scaleFactor: [0.1, 1.0],
  });

  /** Voci del menu "Random behavior every" (tag in secondi, come nel nib originale; testi in i18n.js). */
  const CHANGE_INTERVALS = Object.freeze([[10], [60], [300], [600], [1800], [3600], [0]]);

  const STORAGE_KEY = 'iconvader.preferences';

  function loadPreferences() {
    let stored = {};
    try {
      stored = JSON.parse(global.localStorage.getItem(STORAGE_KEY) || '{}') || {};
    } catch (e) {
      stored = {};
    }
    const prefs = { ...DEFAULT_PREFERENCES, ...stored };
    for (const [key, [min, max]] of Object.entries(PREF_LIMITS)) {
      const v = Number(prefs[key]);
      prefs[key] = Number.isFinite(v) ? Math.min(max, Math.max(min, v)) : DEFAULT_PREFERENCES[key];
    }
    return prefs;
  }

  function savePreferences(prefs) {
    try {
      global.localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
    } catch (e) {
      /* archiviazione non disponibile: le preferenze restano solo per questa sessione */
    }
  }

  // ---------------------------------------------------------------------------
  // Caricamento dei set di icone
  // ---------------------------------------------------------------------------
  const ICON_SETS = Object.freeze({
    Christmas: ['Gingerbread', 'Houx', 'RedHeart', 'Rudolf', 'Santa', 'Snowman', 'Sock'],
    Daedale: ['Alfred', 'EightBall', 'IcoNVader', 'KeepAnEye', 'MacReporter', 'Mushroom', 'iLamp'],
  });

  const iconCache = new Map();

  function loadIconSet(name, basePath) {
    if (iconCache.has(name)) return iconCache.get(name);
    const names = ICON_SETS[name] || ICON_SETS.Christmas;
    const promise = Promise.all(names.map((n) => new Promise((resolve) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => resolve(null);
      img.src = `${basePath}/${encodeURIComponent(name)}/${encodeURIComponent(n)}.png`;
    }))).then((imgs) => imgs.filter(Boolean));
    iconCache.set(name, promise);
    return promise;
  }

  // ---------------------------------------------------------------------------
  // Salvaschermo (IVScreenView)
  // ---------------------------------------------------------------------------
  class ScreenSaver {
    constructor(canvas, options = {}) {
      this.canvas = canvas;
      this.renderer = new Renderer(canvas);
      this.iconBasePath = options.iconBasePath || 'icons';
      this.onBehaviorChange = options.onBehaviorChange || (() => {});
      this.prefs = loadPreferences();
      this.behavior = null;
      this.behaviorChangeTimer = null;
      this.running = false;
      this.lastTime = 0;
      this.accumulator = 0;
      this.generation = 0;
      this._frame = this._frame.bind(this);
      this._onResize = this._onResize.bind(this);
    }

    get bounds() {
      return { x: 0, y: 0, width: this.renderer.width, height: this.renderer.height };
    }

    behaviorClass(identifier) {
      return behaviorRegistry.find((c) => c.identifier === identifier) || behaviorRegistry[0];
    }

    /** -[IVScreenView startAnimation]: sceglie il comportamento, carica le icone, crea tutto. */
    async startAnimation() {
      const gen = ++this.generation;
      const prefs = this.prefs;
      clearTimeout(this.behaviorChangeTimer);
      this.behaviorChangeTimer = null;

      let cls;
      if (prefs.randomBehavior) {
        cls = behaviorRegistry[random() % behaviorRegistry.length];
        if (prefs.randomBehaviorChangeInterval > 0) {
          this.behaviorChangeTimer = setTimeout(
            () => this.startAnimation(), prefs.randomBehaviorChangeInterval * 1000);
        }
      } else {
        cls = this.behaviorClass(prefs.behavior);
      }

      const icons = await loadIconSet(prefs.iconSet, this.iconBasePath);
      if (gen !== this.generation) return; // superato da un riavvio successivo
      this._onResize();
      this.renderer.backgroundColor = prefs.backgroundColor;
      this.behavior = icons.length
        ? new cls(this.bounds, icons, prefs.density, prefs.lifeExpectancy, prefs.scaleFactor)
        : null;
      this.onBehaviorChange(cls, icons.length > 0);

      if (!this.running) {
        this.running = true;
        global.addEventListener('resize', this._onResize);
        this.lastTime = performance.now();
        this.accumulator = 0;
        global.requestAnimationFrame(this._frame);
      }
    }

    stopAnimation() {
      this.running = false;
      this.generation++;
      clearTimeout(this.behaviorChangeTimer);
      global.removeEventListener('resize', this._onResize);
    }

    setPreferences(prefs) {
      this.prefs = { ...this.prefs, ...prefs };
      savePreferences(this.prefs);
      return this.startAnimation();
    }

    _onResize() {
      const w = global.innerWidth;
      const h = global.innerHeight;
      if (w !== this.renderer.width || h !== this.renderer.height || this.renderer.dpr !== (global.devicePixelRatio || 1)) {
        this.renderer.setFrameSize(w, h);
        if (this.behavior) this.behavior.setBounds(this.bounds);
      }
    }

    /** Il timer di animazione dell'originale vale 1/animationSpeed secondi. */
    _frame(now) {
      if (!this.running) return;
      const step = 1000 / this.prefs.animationSpeed;
      this.accumulator += Math.min(now - this.lastTime, 250);
      this.lastTime = now;
      let advanced = false;
      while (this.accumulator >= step) {
        this.accumulator -= step;
        if (this.behavior) this.behavior.animateOneFrame();
        advanced = true;
      }
      if (advanced) {
        if (this.behavior) {
          this.renderer.renderActors(this.behavior.actors);
        } else {
          this.renderer.renderActors([]);
        }
      }
      global.requestAnimationFrame(this._frame);
    }
  }

  global.IcoNVader = {
    LONG_MAX,
    DEG,
    random,
    SSRandomIntBetween,
    SSRandomFloatBetween,
    Actor,
    Behavior,
    Renderer,
    ScreenSaver,
    registerBehavior,
    behaviors: behaviorRegistry,
    ICON_SETS,
    DEFAULT_PREFERENCES,
    PREF_LIMITS,
    CHANGE_INTERVALS,
  };
})(window);
