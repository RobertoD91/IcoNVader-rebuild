/* IcoNVader (ricostruzione web) — pannello opzioni e avvio */
(function () {
  'use strict';
  const IV = window.IcoNVader;

  const canvas = document.getElementById('screen');
  const panel = document.getElementById('panel');
  const toggle = document.getElementById('toggle');
  const current = document.getElementById('current');
  const iconPreview = document.getElementById('iconPreview');
  const RANDOM = '__random__';

  const saver = new IV.ScreenSaver(canvas, {
    iconBasePath: 'icons',
    onBehaviorChange(cls, ok) {
      current.textContent = ok ? cls.displayName : 'nessuna icona caricata';
    },
  });

  // --- Popolamento dei menu (come populateBehaviorMenu / populateIconMenu) ---
  const behaviorSelect = panel.elements.behavior;
  behaviorSelect.add(new Option('Casuale', RANDOM));
  for (const cls of IV.behaviors) behaviorSelect.add(new Option(cls.displayName, cls.identifier));

  const intervalSelect = panel.elements.randomBehaviorChangeInterval;
  for (const [seconds, label] of IV.CHANGE_INTERVALS) intervalSelect.add(new Option(label, String(seconds)));

  const iconSetSelect = panel.elements.iconSet;
  for (const name of Object.keys(IV.ICON_SETS)) iconSetSelect.add(new Option(name, name));

  function showIconPreview(setName) {
    iconPreview.replaceChildren(...(IV.ICON_SETS[setName] || []).map((n) => {
      const img = new Image(32, 32);
      img.src = `icons/${encodeURIComponent(setName)}/${encodeURIComponent(n)}.png`;
      img.alt = n;
      img.title = n;
      return img;
    }));
  }

  const formatters = {
    lifeExpectancy: (v) => `${v} fotogrammi`,
    density: (v) => `${v}`,
    animationSpeed: (v) => `${v} fps`,
    scaleFactor: (v) => `${Math.round(v * 100)}%`,
  };

  function refreshOutputs() {
    for (const [name, fmt] of Object.entries(formatters)) {
      panel.querySelector(`output[for=${name}]`).textContent = fmt(Number(panel.elements[name].value));
    }
    intervalSelect.disabled = behaviorSelect.value !== RANDOM;
  }

  function fillForm(prefs) {
    behaviorSelect.value = prefs.randomBehavior ? RANDOM : prefs.behavior;
    intervalSelect.value = String(prefs.randomBehaviorChangeInterval);
    if (intervalSelect.selectedIndex < 0) intervalSelect.value = '300';
    for (const name of Object.keys(formatters)) panel.elements[name].value = prefs[name];
    iconSetSelect.value = prefs.iconSet;
    panel.elements.backgroundColor.value = prefs.backgroundColor;
    showIconPreview(prefs.iconSet);
    refreshOutputs();
  }

  function readForm() {
    const random = behaviorSelect.value === RANDOM;
    return {
      randomBehavior: random,
      behavior: random ? saver.prefs.behavior : behaviorSelect.value,
      randomBehaviorChangeInterval: Number(intervalSelect.value),
      lifeExpectancy: Number(panel.elements.lifeExpectancy.value),
      density: Number(panel.elements.density.value),
      animationSpeed: Number(panel.elements.animationSpeed.value),
      scaleFactor: Number(panel.elements.scaleFactor.value),
      iconSet: iconSetSelect.value,
      backgroundColor: panel.elements.backgroundColor.value,
    };
  }

  function openPanel() {
    fillForm(saver.prefs);
    panel.hidden = false;
    toggle.hidden = true;
    toggle.setAttribute('aria-expanded', 'true');
  }

  function closePanel() {
    panel.hidden = true;
    toggle.hidden = false;
    toggle.setAttribute('aria-expanded', 'false');
  }

  panel.addEventListener('input', refreshOutputs);
  iconSetSelect.addEventListener('change', () => showIconPreview(iconSetSelect.value));
  panel.addEventListener('submit', (e) => {
    e.preventDefault();
    saver.setPreferences(readForm());
    closePanel();
  });
  document.getElementById('cancel').addEventListener('click', closePanel);
  document.getElementById('reset').addEventListener('click', () => fillForm(IV.DEFAULT_PREFERENCES));
  toggle.addEventListener('click', openPanel);

  // --- Tastiera: P opzioni, F schermo intero, spazio/N comportamento successivo ---
  document.addEventListener('keydown', (e) => {
    if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement) return;
    const key = e.key.toLowerCase();
    if (key === 'p') {
      if (panel.hidden) openPanel(); else closePanel();
    } else if (key === 'escape' && !panel.hidden) {
      closePanel();
    } else if (key === 'f') {
      if (document.fullscreenElement) document.exitFullscreen();
      else if (document.documentElement.requestFullscreen) document.documentElement.requestFullscreen().catch(() => {});
    } else if ((key === ' ' || key === 'n') && panel.hidden) {
      e.preventDefault();
      saver.startAnimation();
    }
  });

  // --- Il cursore e i controlli spariscono dopo qualche secondo di inattività ---
  let idleTimer = 0;
  function wake() {
    document.body.classList.remove('idle');
    clearTimeout(idleTimer);
    idleTimer = setTimeout(() => {
      if (panel.hidden) document.body.classList.add('idle');
    }, 2500);
  }
  ['mousemove', 'mousedown', 'keydown', 'touchstart'].forEach((t) => document.addEventListener(t, wake, { passive: true }));
  wake();

  // Parametri URL opzionali, es. ?behavior=DNA&icons=Daedale
  const params = new URLSearchParams(location.search);
  const urlPrefs = {};
  if (params.has('behavior')) {
    urlPrefs.behavior = params.get('behavior');
    urlPrefs.randomBehavior = false;
  }
  if (params.has('icons') && IV.ICON_SETS[params.get('icons')]) urlPrefs.iconSet = params.get('icons');
  if (Object.keys(urlPrefs).length) saver.prefs = { ...saver.prefs, ...urlPrefs };

  saver.startAnimation();
})();
