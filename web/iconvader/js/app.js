/* IcoNVader (ricostruzione web) — pannello opzioni, traduzioni e avvio */
(function () {
  'use strict';
  const IV = window.IcoNVader;
  const STRINGS = window.IcoNVaderStrings || {};
  const LANGUAGES = Object.keys(STRINGS);

  const canvas = document.getElementById('screen');
  const panel = document.getElementById('panel');
  const toggle = document.getElementById('toggle');
  const hint = document.getElementById('hint');
  const iconPreview = document.getElementById('iconPreview');
  const RANDOM = '__random__';

  // --- Traduzioni (testi originali inglesi e francesi, più l'italiano) ---

  /** Lingua effettiva: quella scelta, altrimenti la prima del browser disponibile, altrimenti inglese. */
  function resolveLanguage(choice) {
    if (LANGUAGES.includes(choice)) return choice;
    for (const tag of navigator.languages || [navigator.language || 'en']) {
      const code = String(tag).slice(0, 2).toLowerCase();
      if (LANGUAGES.includes(code)) return code;
    }
    return 'en';
  }

  let lang = 'en';
  function t(key, vars) {
    let s = (STRINGS[lang] && STRINGS[lang][key]) || (STRINGS.en && STRINGS.en[key]) || key;
    if (vars) for (const [k, v] of Object.entries(vars)) s = s.replace(`{${k}}`, v);
    return s;
  }

  let currentBehavior = null;
  let iconsOk = true;

  function applyLanguage(choice) {
    lang = resolveLanguage(choice);
    document.documentElement.lang = lang;
    const vars = { version: window.IcoNVaderVersion || '' };
    for (const el of document.querySelectorAll('[data-i18n]')) el.textContent = t(el.dataset.i18n, vars);
    toggle.title = t('web.options');
    toggle.setAttribute('aria-label', t('web.options'));
    populateMenus();
    updateHint();
  }

  function updateHint() {
    const name = !iconsOk ? t('web.noIcons') : currentBehavior ? t(`behavior.${currentBehavior.identifier}`) : '…';
    hint.textContent = t('web.hint', { behavior: name });
  }

  const saver = new IV.ScreenSaver(canvas, {
    iconBasePath: 'icons',
    onBehaviorChange(cls, ok) {
      currentBehavior = cls;
      iconsOk = ok;
      updateHint();
    },
  });

  // --- Menu (populateBehaviorMenu / populateIconMenu dell'originale) ---
  const behaviorSelect = panel.elements.behavior;
  const intervalSelect = panel.elements.randomBehaviorChangeInterval;
  const iconSetSelect = panel.elements.iconSet;
  const languageSelect = panel.elements.language;

  function populateMenus() {
    const keep = [behaviorSelect.value, intervalSelect.value, iconSetSelect.value];
    behaviorSelect.replaceChildren(new Option(t('behavior.Random'), RANDOM));
    const sep = new Option('──────────', '');
    sep.disabled = true;
    behaviorSelect.add(sep);
    for (const cls of IV.behaviors) behaviorSelect.add(new Option(t(`behavior.${cls.identifier}`), cls.identifier));
    intervalSelect.replaceChildren(...IV.CHANGE_INTERVALS.map(([s]) => new Option(t(`interval.${s}`), String(s))));
    iconSetSelect.replaceChildren(...Object.keys(IV.ICON_SETS).map((n) => new Option(n, n)));
    if (keep[0]) behaviorSelect.value = keep[0];
    if (keep[1]) intervalSelect.value = keep[1];
    if (keep[2]) iconSetSelect.value = keep[2];
  }

  /** Striscia delle icone del set (oIconTable: una riga, una colonna per icona). */
  function showIconPreview(setName) {
    iconPreview.replaceChildren(...(IV.ICON_SETS[setName] || []).map((n) => {
      const img = new Image(64, 64);
      img.src = `icons/${encodeURIComponent(setName)}/${encodeURIComponent(n)}.png`;
      img.alt = n;
      img.title = n;
      return img;
    }));
  }

  // --- Schede ---
  const tabs = [...panel.querySelectorAll('[role=tab]')];
  function selectTab(tab) {
    for (const t2 of tabs) {
      const on = t2 === tab;
      t2.setAttribute('aria-selected', String(on));
      t2.tabIndex = on ? 0 : -1;
      document.getElementById(t2.getAttribute('aria-controls')).hidden = !on;
    }
  }
  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => selectTab(tab));
    tab.addEventListener('keydown', (e) => {
      if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
      const next = tabs[(i + (e.key === 'ArrowRight' ? 1 : tabs.length - 1)) % tabs.length];
      selectTab(next);
      next.focus();
    });
  });

  // --- Valori ---
  const SLIDERS = ['lifeExpectancy', 'density', 'animationSpeed', 'scaleFactor'];

  function fillForm(prefs) {
    behaviorSelect.value = prefs.randomBehavior ? RANDOM : prefs.behavior;
    intervalSelect.value = String(prefs.randomBehaviorChangeInterval);
    if (intervalSelect.selectedIndex < 0) intervalSelect.value = '300';
    for (const name of SLIDERS) panel.elements[name].value = prefs[name];
    iconSetSelect.value = prefs.iconSet;
    panel.elements.backgroundColor.value = prefs.backgroundColor;
    languageSelect.value = LANGUAGES.includes(prefs.language) ? prefs.language : 'auto';
    showIconPreview(prefs.iconSet);
    behaviorChanged();
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
      language: languageSelect.value,
    };
  }

  /** Come nell'originale, l'intervallo vale solo con il comportamento casuale. */
  function behaviorChanged() {
    intervalSelect.disabled = behaviorSelect.value !== RANDOM;
  }

  function openPanel() {
    fillForm(saver.prefs);
    panel.hidden = false;
    toggle.hidden = true;
    toggle.setAttribute('aria-expanded', 'true');
  }

  function closePanel() {
    // Annulla: si torna alla lingua salvata se era stata solo provata
    applyLanguage(saver.prefs.language);
    panel.hidden = true;
    toggle.hidden = false;
    toggle.setAttribute('aria-expanded', 'false');
  }

  behaviorSelect.addEventListener('change', behaviorChanged);
  iconSetSelect.addEventListener('change', () => showIconPreview(iconSetSelect.value));
  languageSelect.addEventListener('change', () => applyLanguage(languageSelect.value));
  panel.addEventListener('submit', (e) => {
    e.preventDefault();
    saver.setPreferences(readForm());
    closePanel();
  });
  document.getElementById('cancel').addEventListener('click', closePanel);
  toggle.addEventListener('click', openPanel);

  // --- Tastiera: P opzioni, F schermo intero, spazio/N riavvio ---
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
  ['mousemove', 'mousedown', 'keydown', 'touchstart'].forEach((ev) => document.addEventListener(ev, wake, { passive: true }));
  wake();

  // Parametri URL opzionali, es. ?behavior=DNA&icons=Daedale&lang=fr
  const params = new URLSearchParams(location.search);
  const urlPrefs = {};
  if (params.has('behavior')) {
    urlPrefs.behavior = params.get('behavior');
    urlPrefs.randomBehavior = false;
  }
  if (params.has('icons') && IV.ICON_SETS[params.get('icons')]) urlPrefs.iconSet = params.get('icons');
  if (LANGUAGES.includes(params.get('lang'))) urlPrefs.language = params.get('lang');
  if (Object.keys(urlPrefs).length) saver.prefs = { ...saver.prefs, ...urlPrefs };

  applyLanguage(saver.prefs.language);
  saver.startAnimation();
})();
