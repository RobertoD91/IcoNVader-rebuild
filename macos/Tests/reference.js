// Esegue un comportamento della versione web in Node con lo stesso generatore casuale
// deterministico di main.swift e stampa lo stato degli attori nello stesso formato.
//
// Uso: node reference.js <Comportamento> <fotogrammi> <seme> [larghezza altezza]
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const [behaviorId, framesArg, seedArg, wArg, hArg] = process.argv.slice(2);
const frames = Number(framesArg);
const width = Number(wArg || 1440);
const height = Number(hArg || 900);

/** mulberry32: stesso algoritmo di main.swift. */
function mulberry32(a) {
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const web = path.resolve(__dirname, '../../web/iconvader/js');
const files = ['core.js', 'behaviors/comets.js', 'behaviors/fireworks.js', 'behaviors/gameoflife.js',
  'behaviors/hypnosis.js', 'behaviors/dna.js', 'behaviors/jumpers.js'];

const context = vm.createContext({ console });
context.window = context;
vm.runInContext(`Math.random = (${mulberry32.toString()})(${Number(seedArg) >>> 0});`, context);
for (const f of files) vm.runInContext(fs.readFileSync(path.join(web, f), 'utf8'), context, { filename: f });

const IV = context.IcoNVader;
const cls = IV.behaviors.find((c) => c.identifier === behaviorId);
if (!cls) {
  console.error(`comportamento sconosciuto: ${behaviorId}`);
  process.exit(2);
}
const icons = Array.from({ length: 7 }, (_, index) => ({ index, naturalWidth: 128, naturalHeight: 128 }));
const behavior = new cls({ x: 0, y: 0, width, height }, icons, 50, 1200, 0.6);
for (let i = 0; i < frames; i++) behavior.animateOneFrame();

const fmt = (v) => v.toFixed(6);
for (const a of [...behavior.actors].sort((p, q) => p.identifier - q.identifier)) {
  console.log(`{"id":${a.identifier},"x":${fmt(a.location.x)},"y":${fmt(a.location.y)},"angle":${fmt(a.angle)},` +
    `"sx":${fmt(a.scale.x)},"sy":${fmt(a.scale.y)},"opacity":${fmt(a.opacity)},"image":${a.image ? a.image.index : -1}}`);
}
