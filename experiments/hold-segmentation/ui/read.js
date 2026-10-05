// Read-a-line flow: shutter → scan → contours → tap one, light the colour group → correct → start/finish.
const $ = id => document.getElementById(id);
const R = { line: new Set(), seed: null, groups: [], gi: 0, lowSat: false, manualStart: null, manualFinish: null, pix: null };

function setHint(text) { const h = $('hint'); if (!text) { h.classList.remove('on'); return; } h.textContent = text; h.classList.add('on'); }
let toastTimer;
function toast(text, undo) {
  const t = $('toast'); t.querySelector('span').textContent = text; t.classList.add('on');
  const b = t.querySelector('button'); b.style.display = undo ? '' : 'none';
  b.onclick = () => { undo(); t.classList.remove('on'); };
  clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('on'), 3200);
}
function hideMenu() { $('menu').classList.remove('on'); }
function showMenu(sx, sy, items) {
  const m = $('menu'); m.innerHTML = '';
  for (const [label, fn, danger] of items) {
    const b = document.createElement('button'); b.textContent = label; if (danger) b.className = 'danger';
    b.onclick = e => { e.stopPropagation(); hideMenu(); fn(); }; m.appendChild(b);
  }
  m.style.left = Math.min(sx, SW - 184) + 'px'; m.style.top = Math.min(sy + 8, SH - 160) + 'px';
  requestAnimationFrame(() => m.classList.add('on'));
}

// ---------- start / camera ----------
async function start(name) {
  S.mode = 'loading'; S.hooks = S.hooks.filter(f => f.keep);
  for (const k of ['line']) R[k] = new Set();
  Object.assign(R, { seed: null, groups: [], gi: 0, lowSat: false, manualStart: null, manualFinish: null });
  await loadWall(name);
  const c = document.createElement('canvas'); c.width = S.wall.w; c.height = S.wall.h;
  const cc = c.getContext('2d'); cc.drawImage(S.img, 0, 0, S.wall.w, S.wall.h); R.pix = cc.getImageData(0, 0, c.width, c.height).data;
  const s = Math.max(SW / S.wall.w, SH / S.wall.h);
  S.cam = { x: S.wall.w / 2, y: S.wall.h / 2, s, cy: SH / 2 }; S.camTw = null; S.dim = 0; S._dim = null; S.scanY = null;
  $('title').textContent = ''; $('bodyChip').style.visibility = 'hidden';
  $('shutter').classList.remove('hidden'); $('done').classList.add('hidden'); $('simbar').classList.add('hidden');
  $('capsule').classList.remove('on'); $('card').classList.remove('on'); setHint('');
  window.leaveSim?.();
  S.mode = 'camera';
}

$('shutter').onclick = () => {
  if (S.mode !== 'camera') return;
  S.mode = 'scanning';
  const f = $('flash'); f.style.transition = 'none'; f.style.opacity = .85;
  requestAnimationFrame(() => { f.style.transition = 'opacity .35s'; f.style.opacity = 0; });
  $('shutter').classList.add('hidden');
  $('title').textContent = '读线';
  tw(S, 'dim', 1, 250, 150);
  moveCam(fitRect(wallBox(), 110, SH - 210, .06), 550);
  setTimeout(scan, 450);
};
function wallBox() {
  const hs = S.holds; return [Math.min(...hs.map(h => h.bb[0])), Math.min(...hs.map(h => h.bb[1])), Math.max(...hs.map(h => h.bb[2])), Math.max(...hs.map(h => h.bb[3]))];
}

// The band position stands for segmentation progress (rows processed bottom → top).
function scan() {
  const [, y0, , y1] = wallBox(), from = y1 + 30, to = y0 - 30, dur = S.reduce ? 600 : 2200, t0 = now();
  const pending = [...S.holds].sort((a, b) => b.y - a.y);
  S.scanA = 1; S._scanA = null;
  const tick = () => {
    const p = clamp((now() - t0) / dur, 0, 1);
    // a short hold mid-way reads as "still working" rather than a fixed animation
    const q = p < .45 ? p / .45 * .52 : p < .6 ? .52 + (p - .45) / .15 * .03 : .55 + (p - .6) / .4 * .45;
    S.scanY = from + (to - from) * easeInOut(q);
    while (pending.length && pending[0].y > S.scanY) { const h = pending.shift(); h.dotT0 = now(); h._dot = null; h.dot = 1; }
    if (p < 1) return requestAnimationFrame(tick);
    tw(S, 'scanA', 0, 220);
    setTimeout(() => { S.scanY = null; }, 240);
    [...S.holds].sort((a, b) => b.y - a.y).forEach((h, i) => { tw(h, 'dot', 0, 200, 100 + i * 10); tw(h, 'contour', .45, 350, 100 + i * 10); });
    setTimeout(() => { S.mode = 'contours'; setHint('点一个你要爬的点'); }, 100 + S.holds.length * 10 + 200);
  };
  tick();
}

// ---------- colour groups ----------
const hueDiff = (a, b) => { const d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d; };
function sameColour(seed, h) {
  if (h === seed) return true;
  if (h.volume || h.manual) return false;
  if (seed.chroma < 14) return h.chroma < 14 && Math.abs(h.lab[0] - seed.lab[0]) < 12;
  return h.chroma >= Math.max(14, .7 * seed.chroma) && hueDiff(h.hue, seed.hue) <= 16 && Math.abs(h.lab[0] - seed.lab[0]) <= 40;
}
function allGroups() {
  const pool = S.holds.filter(h => !h.volume && !h.manual && h.chroma >= 14).sort((a, b) => b.chroma - a.chroma);
  const groups = [], used = new Set();
  for (const s of pool) {
    if (used.has(s)) continue;
    const g = pool.filter(h => !used.has(h) && sameColour(s, h));
    if (g.length >= 3) { g.forEach(h => used.add(h)); groups.push(s); }
  }
  return groups;
}

function lightGroup(seed, fromX, fromY, expand = false) {
  R.seed = seed; R.lowSat = seed.chroma < 14;
  const members = (R.lowSat && !expand) ? [seed] : S.holds.filter(h => sameColour(seed, h));
  const t = now();
  ripple(fromX, fromY, 120);
  for (const h of members) {
    const d = Math.hypot(h.x - fromX, h.y - fromY) * S.cam.s, delay = h === seed ? 0 : 40 + d / 100 * 35;
    R.line.add(h); tw(h, 'lit', 1, 250, delay); h.popT0 = t + delay; h.litAt = t + delay;
  }
  for (const h of S.holds) if (!R.line.has(h)) tw(h, 'contour', .12, 400);
  const last = Math.max(...members.map(h => h.litAt)) - t;
  renumber(0);
  const name = colourName(seed);
  $('capsule').querySelector('.sw').style.background = seed.rgb;
  $('capsule').querySelector('.lab').textContent = `${name} · ${members.length} 个`;
  $('similar').style.display = R.lowSat && !expand ? 'block' : 'none';
  $('capsule').classList.add('on');
  setTimeout(() => {
    placeEnds(true);
    $('done').classList.remove('hidden');
    setHint(R.lowSat && !expand ? `${name}色容易认错，只亮了这一个 · 点"找相似"展开` : '点亮的点再点一下就移出 · 暗的轮廓点一下加进来 · 长按改起步 / 结束');
  }, last + 300);
  S.mode = 'picked';
}
function clearLine(dur = 200) {
  for (const h of R.line) { tw(h, 'lit', 0, dur); h.num = 0; h.numT0 = 0; h.startT0 = 0; h.flagT0 = 0; }
  R.line = new Set(); R.manualStart = R.manualFinish = null;
}

function ordered() { return [...R.line].sort((a, b) => Math.abs(a.ayp - b.ayp) > 3 ? b.ayp - a.ayp : a.axp - b.axp); }
function renumber(delay = 0) {
  ordered().forEach((h, i) => { if (h.num !== i + 1 || !h.numT0) { h.num = i + 1; h.numT0 = Math.max(now() + delay, (h.litAt || 0) + 100); } });
  const label = $('capsule').querySelector('.lab');
  if (R.seed) label.textContent = `${colourName(R.seed)} · ${R.line.size} 个`;
}
function placeEnds(animate) {
  const o = ordered(); if (!o.length) return;
  const start = R.manualStart && R.line.has(R.manualStart) ? R.manualStart : o[0];
  const finish = R.manualFinish && R.line.has(R.manualFinish) ? R.manualFinish : o[o.length - 1];
  for (const h of S.holds) {
    if (h !== start) h.startT0 = 0; else if (!h.startT0 || animate) h.startT0 = now();
    if (h !== finish || o.length < 2) h.flagT0 = 0; else if (!h.flagT0 || animate) h.flagT0 = now() + 150;
  }
  R.start = start; R.finish = o.length > 1 ? finish : null;
}

// ---------- corrections ----------
function addHold(h, x, y) {
  R.line.add(h); tw(h, 'lit', 1, 200); h.popT0 = now(); ripple(x, y, 60);
  renumber(); placeEnds(false);
}
function removeHold(h) { R.line.delete(h); tw(h, 'lit', 0, 200); tw(h, 'contour', .45, 200); h.num = 0; h.numT0 = 0; renumber(); placeEnds(false); }
function circleHold(x, y) {
  const r = 14 / S.cam.s, pts = [];
  for (let i = 0; i < 24; i++) { const a = i / 24 * Math.PI * 2; pts.push([x + Math.cos(a) * r, y + Math.sin(a) * r]); }
  const lab = sampleLab(x, y, r * .6);
  const h = { id: 'm' + Date.now(), manual: true, pts, per: 2 * Math.PI * r, top: [x, y - r], bb: [x - r, y - r, x + r, y + r], x, y, axp: x, ayp: y,
    area: Math.PI * r * r / (S.wall.w * S.wall.h), lab, chroma: Math.hypot(lab[1], lab[2]), contour: 0 };
  h.hue = hueOf(h); h.rgb = lab2rgb(lab);
  S.holds.push(h); return h;
}
function sampleLab(x, y, r) {
  const L = [], A = [], B = [];
  for (let yy = Math.round(y - r); yy <= y + r; yy += 2) for (let xx = Math.round(x - r); xx <= x + r; xx += 2) {
    if (xx < 0 || yy < 0 || xx >= S.wall.w || yy >= S.wall.h) continue;
    const i = (yy * S.wall.w + xx) * 4, q = rgb2lab(R.pix[i], R.pix[i + 1], R.pix[i + 2]); L.push(q[0]); A.push(q[1]); B.push(q[2]);
  }
  const med = a => a.sort((p, q) => p - q)[a.length >> 1] ?? 0;
  return [med(L), med(A), med(B)];
}
function rgb2lab(r, g, b) {
  const lin = c => (c /= 255) <= .04045 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4;
  const [R_, G, B] = [lin(r), lin(g), lin(b)];
  const f = t => t > .008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116;
  const X = (.4124 * R_ + .3576 * G + .1805 * B) / .95047, Y = .2126 * R_ + .7152 * G + .0722 * B, Z = (.0193 * R_ + .1192 * G + .9505 * B) / 1.08883;
  return [116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z))];
}

// ---------- pointer routing ----------
let press = null;
$('phone').addEventListener('pointerdown', e => {
  if (e.target !== $('scene')) return;
  hideMenu();
  const r = $('phone').getBoundingClientRect(), sx = e.clientX - r.left, sy = e.clientY - r.top;
  if (S.mode === 'sim' || S.mode === 'playing') return window.simDown?.(sx, sy, e);
  press = { sx, sy, t: now(), long: false };
  press.timer = setTimeout(() => { press.long = true; longPress(sx, sy); }, 350);
});
$('phone').addEventListener('pointermove', e => {
  const r = $('phone').getBoundingClientRect(), sx = e.clientX - r.left, sy = e.clientY - r.top;
  if (S.mode === 'sim') return window.simMove?.(sx, sy, e);
  if (press && Math.hypot(sx - press.sx, sy - press.sy) > 8) { clearTimeout(press.timer); press = null; }
});
window.addEventListener('pointerup', e => {
  const r = $('phone').getBoundingClientRect(), sx = e.clientX - r.left, sy = e.clientY - r.top;
  if (S.mode === 'sim') return window.simUp?.(sx, sy, e);
  if (!press) return;
  clearTimeout(press.timer);
  if (!press.long) tap(press.sx, press.sy);
  press = null;
});

function tap(sx, sy) {
  const [x, y] = toImage(sx, sy), h = holdAt(x, y, 16 / S.cam.s);
  if (S.mode === 'contours') {
    lightGroup(h || circleHold(x, y), x, y);
  } else if (S.mode === 'picked') {
    if (h && R.line.has(h)) { removeHold(h); toast('移出了 1 个点', () => addHold(h, h.x, h.y)); }
    else if (h) { addHold(h, x, y); toast('加进来 1 个点', () => removeHold(h)); }
    else { const c = circleHold(x, y); addHold(c, x, y); toast('这里没抠到形状，先用圆圈', () => removeHold(c)); }
  }
}
function longPress(sx, sy) {
  if (S.mode !== 'picked') return;
  const [x, y] = toImage(sx, sy), h = holdAt(x, y, 16 / S.cam.s); if (!h) return;
  if (!R.line.has(h)) return showMenu(sx, sy, [['加进这条线', () => addHold(h, h.x, h.y)]]);
  showMenu(sx, sy, [
    ['设为起步', () => { R.manualStart = h; placeEnds(true); }],
    ['设为结束', () => { R.manualFinish = h; placeEnds(true); }],
    ['移出这条线', () => removeHold(h), true],
  ]);
}

// ---------- capsule ----------
function switchGroup(dir) {
  R.groups = allGroups(); if (!R.groups.length) return;
  let i = R.groups.findIndex(g => sameColour(g, R.seed) && sameColour(R.seed, g));
  i = (i + dir + R.groups.length) % R.groups.length;
  const head = R.groups[i], members = S.holds.filter(h => sameColour(head, h));
  const centre = members.reduce((m, h) => Math.hypot(h.x - S.cam.x, h.y - S.cam.y) < Math.hypot(m.x - S.cam.x, m.y - S.cam.y) ? h : m);
  clearLine(); lightGroup(head, centre.x, centre.y);
}
$('prevGroup').onclick = () => switchGroup(-1);
$('nextGroup').onclick = () => switchGroup(1);
$('similar').onclick = () => { const s = R.seed; clearLine(0); lightGroup(s, s.x, s.y, true); };
$('back').onclick = () => {
  if (S.mode === 'picked') { clearLine(); for (const h of S.holds) tw(h, 'contour', .45, 300); $('capsule').classList.remove('on'); $('done').classList.add('hidden'); S.mode = 'contours'; setHint('点一个你要爬的点'); }
  else if (S.mode === 'contours') start($('wallSel').value);
  else if (S.mode === 'sim') window.backToRead?.();
};
$('done').onclick = () => {
  if (!R.line.size || !R.start) return;
  $('done').classList.add('hidden'); $('capsule').classList.remove('on'); setHint('');
  // confirmation sweep: lit holds bump as the band passes
  const [, y0, , y1] = [0, Math.min(...[...R.line].map(h => h.bb[1])), 0, Math.max(...[...R.line].map(h => h.bb[3]))];
  const t0 = now(), dur = S.reduce ? 1 : 900, pend = ordered();
  S.scanA = 1; S._scanA = null;
  const tick = () => {
    const p = clamp((now() - t0) / dur, 0, 1); S.scanY = y1 + 20 + (y0 - 40 - y1) * easeInOut(p);
    while (pend.length && pend[0].y > S.scanY) pend.shift().popT0 = now();
    if (p < 1) return requestAnimationFrame(tick);
    S.scanY = null; window.enterSim?.();
  };
  tick();
};
$('wallSel').onchange = () => start($('wallSel').value);
$('restart').onclick = () => start($('wallSel').value);
$('reduce').onchange = e => { S.reduce = e.target.checked; };
start('wall-yellow'); render();
