// Simulation: body-scaled stick figure, drag limbs onto holds, step film, smooth playback, fall freeze, export.
const B = { H: 170, A: 170, kMul: 1, k: 1, set: false, ground: 0 };
const LIMBS = {
  LH: { root: 'ls', a: 'ua', b: 'la', arm: true, name: '左手', col: '#fff' },
  RH: { root: 'rs', a: 'ua', b: 'la', arm: true, name: '右手', col: ACC },
  LF: { root: 'lh', a: 'th', b: 'sh', arm: false, name: '左脚', col: '#fff' },
  RF: { root: 'rh', a: 'th', b: 'sh', arm: false, name: '右脚', col: ACC },
};
const M = { tgt: {}, anim: {}, drag: null, scrub: null, solved: null, disp: null, steps: [], cur: 0, play: null, u: 0, fall: null, last: now(), alpha: 0, dropT0: 0 };

function dims() {
  const k = B.k * B.kMul, Hk = B.H * k, reach = ((B.A - .22 * B.H) / 2 - .04 * B.H) * k;
  return { k, Hk, tl: .288 * Hk, sw: .22 * Hk, hw: .12 * Hk, ua: .52 * reach, la: .48 * reach, th: .245 * Hk, sh: .246 * Hk, head: .062 * Hk, neck: .05 * Hk };
}
function joints(T, th) {
  const d = dims(), c = Math.cos(th), s = Math.sin(th);
  const at = (x, y) => [T[0] + x * c - y * s, T[1] + x * s + y * c];
  return { d, sc: at(0, -d.tl / 2), hc: at(0, d.tl / 2), ls: at(-d.sw / 2, -d.tl / 2), rs: at(d.sw / 2, -d.tl / 2),
    lh: at(-d.hw / 2, d.tl / 2), rh: at(d.hw / 2, d.tl / 2), head: at(0, -d.tl / 2 - d.neck - d.head) };
}
function cost(T, th, tg) {
  const J = joints(T, th), d = J.d;
  let c = 2 * th * th - 1.2 * T[1] / d.Hk;
  const floorHip = B.ground - .12 * d.Hk; // sitting starts are allowed
  if (J.hc[1] > floorHip) c += 60 * ((J.hc[1] - floorHip) / d.Hk) ** 2;
  for (const [key, L] of Object.entries(LIMBS)) {
    const j = J[L.root], t = tg[key], R = d[L.a] + d[L.b];
    const r = Math.hypot(t[0] - j[0], t[1] - j[1]) / R, over = Math.max(0, r - .97);
    c += 400 * over * over + (L.arm ? .6 : .4) * (r - (L.arm ? .75 : .7)) ** 2;
  }
  return c;
}
function solve(tg, init) {
  const d = dims(); let T = [...init.T], th = init.th, best = cost(T, th, tg), sT = .05 * d.Hk, sA = .15;
  for (let i = 0; i < 70 && sT > .002 * d.Hk; i++) {
    let moved = false;
    for (const [dx, dy, da] of [[sT, 0, 0], [-sT, 0, 0], [0, sT, 0], [0, -sT, 0], [0, 0, sA], [0, 0, -sA]]) {
      const c = cost([T[0] + dx, T[1] + dy], th + da, tg);
      if (c < best) { best = c; T = [T[0] + dx, T[1] + dy]; th += da; moved = true; }
    }
    if (!moved) { sT /= 2; sA /= 2; }
  }
  return { T, th };
}
function ik(j, t, a0, b0, arm, tx) {
  const dx = t[0] - j[0], dy = t[1] - j[1], dist = Math.hypot(dx, dy), ux = dx / (dist || 1), uy = dy / (dist || 1);
  // a folded limb points partly toward the wall, so it reads shorter from behind
  const f = clamp(dist / (a0 + b0) + .3, .6, 1), a = a0 * f, b = b0 * f;
  if (dist >= a + b - .5) return { mid: [j[0] + ux * a, j[1] + uy * a], end: [j[0] + ux * (a + b), j[1] + uy * (a + b)], gap: Math.max(0, dist - (a0 + b0)) };
  const dd = Math.max(dist, Math.abs(a - b) + .5), A = Math.acos(clamp((a * a + dd * dd - b * b) / (2 * a * dd), -1, 1)), phi = Math.atan2(dy, dx);
  const m1 = [j[0] + a * Math.cos(phi + A), j[1] + a * Math.sin(phi + A)], m2 = [j[0] + a * Math.cos(phi - A), j[1] + a * Math.sin(phi - A)];
  const score = m => arm ? m[1] + .4 * Math.abs(m[0] - tx) : .5 * Math.abs(m[0] - tx) - m[1];
  return { mid: score(m1) > score(m2) ? m1 : m2, end: t, gap: 0 };
}

// ---------- enter / leave ----------
window.enterSim = () => {
  S.mode = 'sim';
  const line = [...R.line], ys = line.map(h => h.bb[3]);
  const [, y0, , y1] = wallBox();
  B.k = (y1 - y0) / 380;
  B.ground = Math.min(S.wall.h - 2, Math.max(...ys) + .06 * B.H * B.k);
  $('title').textContent = '计划顺序'; $('bodyChip').style.visibility = 'visible';
  if (!S.hooks.includes(drawFigure)) S.hooks.push(drawFigure);
  if (!B.set) { $('sheet').classList.add('on'); setHint(''); } else placeFigure();
  frameSim();
};
window.leaveSim = () => { S.hooks = S.hooks.filter(f => f !== drawFigure); M.steps = []; $('film').innerHTML = ''; M.alpha = 0; stopPlay(); };
window.backToRead = () => {
  stopPlay(); window.leaveSim(); $('simbar').classList.add('hidden'); $('bodyChip').style.visibility = 'hidden';
  $('title').textContent = '读线'; S.mode = 'picked'; $('done').classList.remove('hidden'); $('capsule').classList.add('on');
  moveCam(fitRect(wallBox(), 110, SH - 210, .06), 550);
};
function frameSim() {
  const line = [...R.line], d = dims();
  const x0 = Math.min(...line.map(h => h.bb[0])) - .35 * d.Hk, x1 = Math.max(...line.map(h => h.bb[2])) + .35 * d.Hk;
  const y0 = Math.min(...line.map(h => h.bb[1])) - .15 * d.Hk;
  moveCam(fitRect([x0, y0, x1, B.ground + .03 * d.Hk], 104, SH - 196, .02), 650);
}
function placeFigure() {
  const d = dims(), st = R.start, alt = [...R.line].find(h => h !== st && Math.abs(h.ayp - st.ayp) < .08 * d.Hk && h.startT0);
  const hand = (dx) => [st.axp + dx, st.ayp];
  M.tgt = { LH: hand(-.02 * d.Hk), RH: alt ? [alt.axp, alt.ayp] : hand(.02 * d.Hk), LF: [st.axp - .12 * d.Hk, B.ground], RF: [st.axp + .12 * d.Hk, B.ground] };
  M.holdOf = { LH: st, RH: alt || st, LF: null, RF: null };
  M.anim = {};
  M.solved = solve(M.tgt, { T: [st.axp, Math.min(st.ayp, B.ground - .3 * d.Hk) - .1 * d.Hk], th: 0 });
  M.disp = { T: [...M.solved.T], th: M.solved.th };
  M.steps = []; M.cur = 0; $('film').innerHTML = ''; M.fall = null;
  M.dropT0 = now();
  pushStep(null);
  $('simbar').classList.remove('hidden');
  setHint('拖手或脚到岩点上，每放一步记一格');
  setTimeout(() => setHint(''), 3600);
}

// ---------- body sheet ----------
const syncBody = () => {
  B.H = +$('hIn').value; B.A = +$('aIn').value; B.kMul = $('kIn').value / 100;
  $('hOut').textContent = B.H + ' cm'; $('aOut').textContent = B.A + ' cm'; $('kOut').textContent = $('kIn').value + '%';
  if (B.set && M.solved) { M.solved = solve(M.tgt, M.solved); }
};
for (const id of ['hIn', 'aIn', 'kIn']) $(id).oninput = () => { if (id === 'hIn' && !$('aIn').dataset.touched) $('aIn').value = $('hIn').value; if (id === 'aIn') $('aIn').dataset.touched = 1; syncBody(); };
$('sheetGo').onclick = () => { $('sheet').classList.remove('on'); const first = !B.set; B.set = true; syncBody(); if (first || !M.steps.length) placeFigure(); frameSim(); };
$('bodyChip').onclick = () => $('sheet').classList.add('on');

// ---------- per-frame ----------
function currentTargets(t) {
  if (M.scrub) return { ...M.scrub };
  const out = {};
  for (const key of Object.keys(LIMBS)) {
    const a = M.anim[key];
    if (M.drag && M.drag.key === key) out[key] = M.drag.p;
    else if (a) {
      const p = clamp((t - a.t0) / a.dur, 0, 1);
      let e = a.kind === 'spring' ? spring((t - a.t0) / 1000, .35, .3) : easeInOut(p);
      if (a.kind === 'arc') { const q = e, u = 1 - q; out[key] = [u * u * a.from[0] + 2 * u * q * a.ctrl[0] + q * q * a.to[0], u * u * a.from[1] + 2 * u * q * a.ctrl[1] + q * q * a.to[1]]; }
      else out[key] = [a.from[0] + (a.to[0] - a.from[0]) * e, a.from[1] + (a.to[1] - a.from[1]) * e];
      if (p >= 1 && (a.kind !== 'spring' || t - a.t0 > 700)) { delete M.anim[key]; out[key] = a.to; }
    } else out[key] = M.tgt[key];
  }
  return out;
}
function drawFigure(c, t) {
  if (!M.disp || !B.set) return;
  if (M.play) stepPlay(t);
  const dt = Math.min(64, t - M.last); M.last = t;
  const tg = currentTargets(t);
  M.solved = solve(tg, M.solved || M.disp);
  const tau = M.play ? 80 : 60, f = S.reduce ? 1 : 1 - Math.exp(-dt / tau);
  M.disp.T = [M.disp.T[0] + (M.solved.T[0] - M.disp.T[0]) * f, M.disp.T[1] + (M.solved.T[1] - M.disp.T[1]) * f];
  M.disp.th += (M.solved.th - M.disp.th) * f;
  const J = joints(M.disp.T, M.disp.th), d = J.d, s = S.cam.s;
  const drop = spring((t - M.dropT0) / 1000, .45, .35);
  c.save(); camTransform(c); c.translate(0, -30 / s * (1 - drop)); c.globalAlpha = clamp(drop * 1.5, 0, 1);
  c.lineCap = 'round'; c.lineJoin = 'round';
  const seg = (pts, col, w) => {
    c.beginPath(); c.moveTo(...pts[0]); pts.slice(1).forEach(p => c.lineTo(...p));
    c.strokeStyle = 'rgba(0,0,0,.55)'; c.lineWidth = (w + 3) / s; c.stroke();
    c.strokeStyle = col; c.lineWidth = w / s; c.stroke();
  };
  seg([J.ls, J.rs], '#fff', 2.5); seg([J.lh, J.rh], '#fff', 2.5); seg([J.sc, J.hc], '#fff', 2.5);
  seg([J.sc, [J.head[0] + (J.sc[0] - J.head[0]) * .55, J.head[1] + (J.sc[1] - J.head[1]) * .55]], '#fff', 2.5);
  c.beginPath(); c.arc(J.head[0], J.head[1], d.head, 0, Math.PI * 2);
  c.strokeStyle = 'rgba(0,0,0,.55)'; c.lineWidth = 5.5 / s; c.stroke(); c.strokeStyle = '#fff'; c.lineWidth = 2.5 / s; c.stroke();
  const ends = {};
  for (const [key, L] of Object.entries(LIMBS)) {
    const r = ik(J[L.root], tg[key], d[L.a], d[L.b], L.arm, J.sc[0]);
    seg([J[L.root], r.mid, r.end], L.col, 2.5);
    ends[key] = r.end;
    if (r.gap > 2) {
      c.setLineDash([4 / s, 4 / s]); c.strokeStyle = 'rgba(255,255,255,.7)'; c.lineWidth = 1.5 / s;
      c.beginPath(); c.moveTo(...r.end); c.lineTo(...tg[key]); c.stroke(); c.setLineDash([]);
      c.save(); c.setTransform(dpr, 0, 0, dpr, 0, 0); const [lx, ly] = toScreen(...tg[key]);
      c.font = '600 11px -apple-system,sans-serif'; c.fillStyle = 'rgba(255,255,255,.8)'; c.textAlign = 'center';
      c.fillText(`差 ${Math.round(r.gap / d.k)}cm`, lx, ly - 12); c.restore();
    }
  }
  for (const [key, L] of Object.entries(LIMBS)) {
    const e = ends[key], active = M.drag?.key === key, idle = S.mode === 'sim' && !M.drag;
    if (idle || active) { c.fillStyle = `rgba(255,255,255,${active ? .2 : .1})`; c.beginPath(); c.arc(e[0], e[1], (active ? 20 : 13) / s, 0, Math.PI * 2); c.fill(); }
    c.fillStyle = 'rgba(0,0,0,.6)'; c.beginPath(); c.arc(e[0], e[1], 6.5 / s, 0, Math.PI * 2); c.fill();
    c.fillStyle = L.col; c.beginPath(); c.arc(e[0], e[1], 4.5 / s, 0, Math.PI * 2); c.fill();
  }
  M.ends = ends; c.restore();
}

// ---------- dragging ----------
function snapFor(key, p) {
  const s = S.cam.s, foot = !LIMBS[key].arm;
  let best = null, bd = 34 / s;
  for (const h of R.line) {
    const dd = inPoly(h.pts, p[0], p[1]) ? 0 : Math.hypot(h.axp - p[0], h.ayp - p[1]);
    if (dd < bd) { bd = dd; best = h; }
  }
  if (!best && foot && p[1] > B.ground - 24 / s) return { ground: true, p: [p[0], B.ground] };
  return best ? { hold: best, p: [best.axp, best.ayp] } : null;
}
window.simDown = (sx, sy) => {
  if ($('card').classList.contains('on')) return resumeFall();
  if (S.mode === 'playing') return stopPlay();
  if (!M.ends) return;
  let best = null, bd = 28;
  for (const [key, e] of Object.entries(M.ends)) { const [ex, ey] = toScreen(...e), dd = Math.hypot(ex - sx, ey - sy); if (dd < bd) { bd = dd; best = key; } }
  if (!best) return;
  M.drag = { key: best, p: toImage(sx, sy), from: [...M.tgt[best]] };
  delete M.anim[best];
  if (M.cur < M.steps.length - 1) M.steps.slice(M.cur + 1).forEach(st => st.el.classList.add('ghost'));
};
window.simMove = (sx, sy) => {
  if (!M.drag) return;
  M.drag.p = toImage(sx, sy);
  const J = joints(M.disp.T, M.disp.th), L = LIMBS[M.drag.key], root = J[L.root], R_ = J.d[L.a] + J.d[L.b], snap = snapFor(M.drag.key, M.drag.p);
  for (const h of R.line) {
    const ok = Math.hypot(h.axp - root[0], h.ayp - root[1]) <= R_ * 1.02;
    tw(h, 'lit', ok ? 1 : .55, 120); tw(h, 'hint', snap?.hold === h ? .9 : 0, 120);
  }
};
window.simUp = () => {
  if (!M.drag) return;
  const { key, p, from } = M.drag, snap = snapFor(key, p);
  M.drag = null;
  for (const h of R.line) { tw(h, 'lit', 1, 200); tw(h, 'hint', 0, 200); }
  if (!snap) { M.anim[key] = { from: p, to: from, t0: now(), dur: 400, kind: 'spring' }; M.steps.forEach(st => st.el.classList.remove('ghost')); return; }
  M.anim[key] = { from: p, to: snap.p, t0: now(), dur: 400, kind: 'spring' };
  if (snap.hold) ripple(snap.p[0], snap.p[1], 42, '255,209,46', 350);
  M.tgt[key] = snap.p; M.holdOf[key] = snap.hold || null;
  M.steps.slice(M.cur + 1).forEach(st => st.el.remove()); M.steps = M.steps.slice(0, M.cur + 1);
  pushStep(key);
};

// ---------- steps & film ----------
function pushStep(moved) {
  const step = { tgt: JSON.parse(JSON.stringify(M.tgt)), holdOf: { ...M.holdOf }, moved };
  const el = document.createElement('div'); el.className = 'cell';
  const cvs = document.createElement('canvas'); cvs.width = 64 * dpr; cvs.height = 80 * dpr;
  const cap = document.createElement('div'); cap.className = 'cap';
  const target = moved && (M.holdOf[moved] ? M.holdOf[moved].num : '地');
  cap.textContent = moved ? `${LIMBS[moved].name} → ${typeof target === 'number' ? String.fromCodePoint(0x2460 + target - 1) : target}` : '起步';
  el.append(cvs, cap); $('film').appendChild(el);
  step.el = el; step.cvs = cvs;
  el.onclick = () => goStep(M.steps.indexOf(step));
  M.steps.push(step); M.cur = M.steps.length - 1;
  if (M.steps.length >= 4 && !M.fall) M.fall = { i: 3 };
  markCells(); updateScrub(M.cur);
  setTimeout(() => snapshot(step), 480);
  requestAnimationFrame(() => { $('film').scrollLeft = $('film').scrollWidth; });
}
function snapshot(step) {
  const c = step.cvs.getContext('2d'), w = SW * dpr, h = w / .8, y = (S.cam.cy * dpr) - h / 2;
  c.drawImage(cv, 0, clamp(y, 0, cv.height - h), w, h, 0, 0, step.cvs.width, step.cvs.height);
}
function markCells() {
  M.steps.forEach((st, i) => { st.el.classList.toggle('cur', i === M.cur); st.el.classList.toggle('fall', M.fall?.i === i); st.el.classList.remove('ghost'); });
}
function goStep(i, dur = 400) {
  if (i < 0) return; stopPlay();
  const st = M.steps[i], t = now(), cur = currentTargets(t);
  M.scrub = null;
  for (const key of Object.keys(LIMBS)) M.anim[key] = { from: cur[key], to: st.tgt[key], t0: t, dur, kind: 'ease' };
  M.tgt = JSON.parse(JSON.stringify(st.tgt)); M.holdOf = { ...st.holdOf }; M.cur = i; markCells(); updateScrub(i);
}

// ---------- playback ----------
function arcCtrl(a, b) {
  const mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2, dx = b[0] - a[0], dy = b[1] - a[1], len = Math.hypot(dx, dy) || 1;
  let nx = -dy / len, ny = dx / len;
  if ((mx - M.disp.T[0]) * nx + (my - M.disp.T[1]) * ny < 0) { nx = -nx; ny = -ny; }
  return [mx + nx * len * .15, my + ny * len * .15];
}
function startPlay(recording = false) {
  if (M.steps.length < 2) return toast('先摆两步再播放');
  goStep(0, 300);
  M.play = { i: 0, t0: now() + 350, rec: recording }; S.mode = 'playing'; $('play').textContent = '❚❚';
}
function stopPlay() { if (!M.play) return; M.play = null; S.mode = 'sim'; $('play').textContent = '▶'; }
function stepPlay(t) {
  const P = M.play; if (!P || P.paused || t < P.t0) return;
  const per = S.reduce ? 1 : 600, p = (t - P.t0) / per;
  if (!P.started) {
    P.started = true; const a = M.steps[P.i], b = M.steps[P.i + 1], key = b.moved;
    if (key) M.anim[key] = { from: a.tgt[key], to: b.tgt[key], ctrl: arcCtrl(a.tgt[key], b.tgt[key]), t0: P.t0, dur: per, kind: S.reduce ? 'ease' : 'arc' };
  }
  updateScrub(P.i + Math.min(1, p));
  if (p < 1) return;
  P.i++; M.cur = P.i; const st = M.steps[P.i];
  M.tgt = JSON.parse(JSON.stringify(st.tgt)); M.holdOf = { ...st.holdOf }; markCells();
  st.el.scrollIntoView({ inline: 'center', behavior: 'smooth', block: 'nearest' });
  const h = st.moved && st.holdOf[st.moved]; if (h) h.popT0 = t;
  if (!P.rec && M.fall?.i === P.i && h) { P.paused = true; pulse(h, 3); showFall(h); return; }
  if (P.i >= M.steps.length - 1) { P.done = true; setTimeout(() => { if (M.play === P) { stopPlay(); P.onDone?.(); } }, 800); P.paused = true; return; }
  P.started = false; P.t0 = t;
}
function showFall(h) {
  $('card').querySelector('.k').textContent = `上次掉在这一步 · ${String.fromCodePoint(0x2460 + h.num - 1)}（演示数据）`;
  $('card').querySelector('.v').textContent = '下次试什么：右脚先踩高再出手';
  // keep the card off the figure: top when the body sits low on screen, bottom otherwise
  const [, ty] = toScreen(...M.disp.T), card = $('card');
  if (ty > SH * .42) { card.style.top = '112px'; card.style.bottom = 'auto'; } else { card.style.top = 'auto'; card.style.bottom = '210px'; }
  card.classList.add('on');
}
function resumeFall() {
  $('card').classList.remove('on'); const P = M.play; if (!P) return;
  if (P.i >= M.steps.length - 1) return stopPlay();
  P.paused = false; P.started = false; P.t0 = now();
}
$('play').onclick = () => M.play ? stopPlay() : startPlay();

// ---------- scrubber ----------
function updateScrub(u) {
  M.u = u; const n = Math.max(1, M.steps.length - 1), pct = (u / n) * 100, sc = $('scrub');
  sc.querySelector('.fill').style.width = pct + '%'; sc.querySelector('.knob').style.left = pct + '%';
  sc.querySelectorAll('.tick').forEach(e => e.remove());
  M.steps.forEach((_, i) => { const tk = document.createElement('div'); tk.className = 'tick' + (M.fall?.i === i ? ' fall' : ''); tk.style.left = (i / n * 100) + '%'; sc.appendChild(tk); });
}
let scrubbing = false;
$('scrub').addEventListener('pointerdown', e => { scrubbing = true; stopPlay(); scrubTo(e); e.stopPropagation(); });
window.addEventListener('pointermove', e => { if (scrubbing) scrubTo(e); });
window.addEventListener('pointerup', () => { if (scrubbing) { scrubbing = false; goStep(Math.round(M.u), 250); } });
function scrubTo(e) {
  const r = $('scrub').getBoundingClientRect(), n = M.steps.length - 1; if (n < 1) return;
  const u = clamp((e.clientX - r.left) / r.width, 0, 1) * n, i = Math.floor(Math.min(u, n - 1e-6)), f = u - i;
  const a = M.steps[i], b = M.steps[Math.min(i + 1, n)];
  for (const key of Object.keys(LIMBS)) {
    const A = a.tgt[key], Bt = b.tgt[key], ctrl = key === b.moved ? arcCtrl(A, Bt) : null, q = f, w = 1 - q;
    const p = ctrl ? [w * w * A[0] + 2 * w * q * ctrl[0] + q * q * Bt[0], w * w * A[1] + 2 * w * q * ctrl[1] + q * q * Bt[1]] : [A[0] + (Bt[0] - A[0]) * q, A[1] + (Bt[1] - A[1]) * q];
    (M.scrub ||= {})[key] = p;
  }
  updateScrub(u);
}

// ---------- export (canvas → video, stays on this page) ----------
$('export').onclick = () => {
  if (M.steps.length < 2) return toast('先摆两步再导出');
  if (!window.MediaRecorder || !cv.captureStream) return toast('这个浏览器不支持录制');
  const stream = cv.captureStream(30), chunks = [];
  const rec = new MediaRecorder(stream, { mimeType: MediaRecorder.isTypeSupported('video/webm;codecs=vp9') ? 'video/webm;codecs=vp9' : 'video/webm' });
  rec.ondataavailable = e => chunks.push(e.data);
  rec.onstop = () => { const v = $('vid').querySelector('video'); v.src = URL.createObjectURL(new Blob(chunks, { type: 'video/webm' })); $('vid').classList.add('on'); v.play(); };
  $('export').textContent = '录制中…'; rec.start();
  startPlay(true); M.play.onDone = () => { rec.stop(); $('export').textContent = '导出'; };
};
$('vid').querySelector('button').onclick = () => { $('vid').classList.remove('on'); $('vid').querySelector('video').pause(); };
