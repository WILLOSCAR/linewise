// Shared scene: data, camera, animation primitives, spotlight renderer.
const ACC = '#FFD12E', CORAL = '#FF7361', INK = '#0D0D12';
const SW = 390, SH = 844;
const S = {
  wall: null, img: null, holds: [], cam: { x: 0, y: 0, s: 1, cy: SH / 2 }, camTw: null,
  reduce: false, scanY: null, ripples: [], pulses: [], hooks: [], mode: 'camera',
};

const now = () => performance.now();
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const easeOut = t => 1 - Math.pow(1 - t, 3);
const easeInOut = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
// SwiftUI-style spring step response, 0 → 1 with overshoot.
function spring(t, dur = .35, bounce = .3) {
  if (t <= 0) return 0;
  if (S.reduce) return 1;
  const w = 2 * Math.PI / dur, z = 1 - bounce, wd = w * Math.sqrt(1 - z * z);
  return 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + (z * w / wd) * Math.sin(wd * t));
}
// Time-based tween stored on an object: tw(o,'lit',1,250) then val(o,'lit').
function tw(o, k, to, dur = 250, delay = 0, ease = easeOut) {
  const from = val(o, k);
  o['_' + k] = { from, to, t0: now() + delay, dur: S.reduce ? 1 : dur, ease };
}
function val(o, k) {
  const a = o['_' + k];
  if (!a) return o[k] ?? 0;
  const p = clamp((now() - a.t0) / a.dur, 0, 1);
  return a.from + (a.to - a.from) * a.ease(p);
}

// ---------- data ----------
function lab2rgb([L, a, b]) {
  let y = (L + 16) / 116, x = a / 500 + y, z = y - b / 200;
  const f = t => t ** 3 > .008856 ? t ** 3 : (t - 16 / 116) / 7.787;
  x = .95047 * f(x); y = f(y); z = 1.08883 * f(z);
  let r = x * 3.2406 + y * -1.5372 + z * -.4986, g = x * -.9689 + y * 1.8758 + z * .0415, bl = x * .0557 + y * -.204 + z * 1.057;
  const c = v => Math.round(255 * clamp(v > .0031308 ? 1.055 * v ** (1 / 2.4) - .055 : 12.92 * v, 0, 1));
  return `rgb(${c(r)},${c(g)},${c(bl)})`;
}
function hueOf(h) { return (Math.atan2(h.lab[2], h.lab[1]) * 180 / Math.PI + 360) % 360; }
function colourName(h) {
  if (h.chroma < 14) return h.lab[0] > 70 ? '白' : h.lab[0] < 30 ? '黑' : '灰';
  const d = hueOf(h);
  if (d < 20 || d >= 345) return '粉';
  if (d < 55) return '红'; if (d < 72) return '橙'; if (d < 105) return '黄';
  if (d < 175) return '绿'; if (d < 235) return '青'; if (d < 290) return '蓝'; return '紫';
}

async function loadWall(name) {
  const [wall, img] = await Promise.all([
    fetch(`data/${name}.json`).then(r => r.json()),
    new Promise(res => { const i = new Image(); i.onload = () => res(i); i.src = `data/${name}.jpg`; }),
  ]);
  S.wall = wall; S.img = img;
  S.holds = wall.holds.map(h => {
    const pts = h.poly.map(([x, y]) => [x * wall.w, y * wall.h]);
    const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
    let per = 0; for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; per += Math.hypot(b[0] - a[0], b[1] - a[1]); }
    const top = pts.reduce((m, p) => p[1] < m[1] ? p : m);
    return { ...h, pts, per, top, bb: [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)],
      x: h.cx * wall.w, y: h.cy * wall.h, axp: h.ax * wall.w, ayp: h.ay * wall.h,
      hue: hueOf(h), volume: h.area > .006, rgb: lab2rgb(h.lab) };
  });
}

// ---------- camera ----------
function fitRect([x0, y0, x1, y1], top, bottom, pad = .12) {
  const w = (x1 - x0) * (1 + pad * 2), h = (y1 - y0) * (1 + pad * 2);
  const s = Math.min(SW / w, (bottom - top) / h);
  return { x: (x0 + x1) / 2, y: (y0 + y1) / 2, s, cy: (top + bottom) / 2 };
}
function moveCam(to, dur = 600) {
  const from = { ...S.cam };
  S.camTw = { from, to, t0: now(), dur: S.reduce ? 1 : dur };
}
function stepCam() {
  const a = S.camTw; if (!a) return;
  const p = easeInOut(clamp((now() - a.t0) / a.dur, 0, 1));
  for (const k of ['x', 'y', 's', 'cy']) S.cam[k] = a.from[k] + (a.to[k] - a.from[k]) * p;
  if (p >= 1) S.camTw = null;
}
const toScreen = (x, y) => [(x - S.cam.x) * S.cam.s + SW / 2, (y - S.cam.y) * S.cam.s + S.cam.cy];
const toImage = (sx, sy) => [(sx - SW / 2) / S.cam.s + S.cam.x, (sy - S.cam.cy) / S.cam.s + S.cam.y];

function inPoly(pts, x, y) {
  let c = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}
function holdAt(x, y, slop = 0) {
  let best = null;
  for (const h of S.holds) {
    const inside = inPoly(h.pts, x, y), d = inside ? 0 : edgeDist(h.pts, x, y);
    if (!inside && (!slop || d > slop)) continue;
    const rank = inside ? h.area : 1e9 + d;
    if (!best || rank < best.rank) best = { h, rank };
  }
  return best?.h ?? null;
}
function edgeDist(pts, x, y) {
  let m = Infinity;
  for (let i = 0; i < pts.length; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[(i + 1) % pts.length], dx = bx - ax, dy = by - ay;
    const t = clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy || 1), 0, 1);
    m = Math.min(m, Math.hypot(ax + t * dx - x, ay + t * dy - y));
  }
  return m;
}

// ---------- rendering ----------
const cv = document.getElementById('scene'), ctx = cv.getContext('2d');
const dpr = window.devicePixelRatio || 1;
cv.width = SW * dpr; cv.height = SH * dpr;
const off = document.createElement('canvas'); off.width = cv.width; off.height = cv.height;
const octx = off.getContext('2d');
const ringCv = document.createElement('canvas'); ringCv.width = cv.width; ringCv.height = cv.height;
const rctx = ringCv.getContext('2d');

function camTransform(c) { const { x, y, s, cy } = S.cam; c.setTransform(dpr * s, 0, 0, dpr * s, dpr * (SW / 2 - x * s), dpr * (cy - y * s)); }
function polyPath(c, h, scale = 1) {
  c.beginPath();
  h.pts.forEach(([px, py], i) => {
    const x = h.x + (px - h.x) * scale, y = h.y + (py - h.y) * scale;
    i ? c.lineTo(x, y) : c.moveTo(x, y);
  });
  c.closePath();
}

function render() {
  stepCam();
  const t = now(), s = S.cam.s;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.fillStyle = INK; ctx.fillRect(0, 0, SW, SH);
  if (!S.img) return requestAnimationFrame(render);
  camTransform(ctx);
  ctx.drawImage(S.img, 0, 0, S.wall.w, S.wall.h);

  // dim overlay with lit holes
  const dim = val(S, 'dim');
  octx.setTransform(1, 0, 0, 1, 0, 0); octx.clearRect(0, 0, off.width, off.height);
  if (dim > 0) {
    octx.globalCompositeOperation = 'source-over';
    octx.fillStyle = `rgba(5,5,10,${.66 * dim})`; octx.fillRect(0, 0, off.width, off.height);
    const g = octx.createRadialGradient(off.width / 2, off.height * .45, off.height * .25, off.width / 2, off.height * .45, off.height * .75);
    g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, `rgba(0,0,0,${.35 * dim})`);
    octx.fillStyle = g; octx.fillRect(0, 0, off.width, off.height);
    octx.globalCompositeOperation = 'destination-out';
    camTransform(octx);
    octx.shadowColor = '#000'; octx.shadowBlur = 2 * dpr;
    for (const h of S.holds) {
      const lit = val(h, 'lit'); if (lit <= .001) continue;
      octx.globalAlpha = lit; polyPath(octx, h, litScale(h, t)); octx.fill();
    }
    octx.globalAlpha = 1; octx.shadowBlur = 0; octx.globalCompositeOperation = 'source-over';
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(off, 0, 0); camTransform(ctx);
  }

  // detected contours (unlit)
  for (const h of S.holds) {
    const c = val(h, 'contour'); if (c <= .001) continue;
    ctx.globalAlpha = c * (1 - val(h, 'lit')); ctx.strokeStyle = '#fff'; ctx.lineWidth = 1 / s;
    polyPath(ctx, h); ctx.stroke();
  }
  ctx.globalAlpha = 1;
  // lit edges + glow
  for (const h of S.holds) {
    const lit = val(h, 'lit'); if (lit <= .001) continue;
    const sc = litScale(h, t), boost = val(h, 'hint');
    ctx.save();
    ctx.shadowColor = `rgba(255,209,46,${.55 * lit})`; ctx.shadowBlur = 16 * dpr;
    ctx.strokeStyle = `rgba(255,209,46,${.45 * lit})`; ctx.lineWidth = 4 / s; polyPath(ctx, h, sc); ctx.stroke();
    ctx.restore();
    ctx.strokeStyle = `rgba(255,209,46,${lit})`; ctx.lineWidth = 1.5 / s; polyPath(ctx, h, sc); ctx.stroke();
    if (boost > .01) { ctx.strokeStyle = `rgba(255,255,255,${boost})`; ctx.lineWidth = 2 / s; polyPath(ctx, h, 1.08); ctx.stroke(); }
  }
  drawStartRings(t); drawFlags(t);
  // scan dots
  for (const h of S.holds) {
    const d = val(h, 'dot'); if (d <= .001) continue;
    const pop = h.dotT0 ? spring((t - h.dotT0) / 1000, .3, .5) : 1;
    ctx.fillStyle = `rgba(255,255,255,${.75 * d})`;
    ctx.beginPath(); ctx.arc(h.x, h.y, 3.2 * pop * d / s, 0, Math.PI * 2); ctx.fill();
  }
  // numbers
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.font = '600 12px -apple-system, "PingFang SC", sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  for (const h of S.holds) {
    if (!h.num || !h.numT0) continue;
    const p = spring((t - h.numT0) / 1000, .3, .45); if (p <= 0) continue;
    const [sx, sy] = toScreen(h.bb[2], h.bb[1]);
    ctx.save(); ctx.translate(sx + 2, sy - 2); ctx.scale(p, p);
    ctx.shadowColor = 'rgba(0,0,0,.9)'; ctx.shadowBlur = 4;
    ctx.fillStyle = '#fff'; ctx.fillText(String.fromCodePoint(0x2460 + h.num - 1), 0, 0); ctx.restore();
  }
  drawRipples(t); drawPulses(t); drawScan();
  for (const f of S.hooks) f(ctx, t);
  requestAnimationFrame(render);
}
function litScale(h, t) {
  if (!h.popT0 || S.reduce) return 1;
  return .92 + .08 * spring((t - h.popT0) / 1000, .3, .35);
}
function drawStartRings(t) {
  const starts = S.holds.filter(h => h.startT0);
  if (!starts.length) return;
  rctx.setTransform(1, 0, 0, 1, 0, 0); rctx.clearRect(0, 0, ringCv.width, ringCv.height);
  const s = S.cam.s;
  for (const h of starts) {
    const p = S.reduce ? 1 : easeInOut(clamp((t - h.startT0) / 500, 0, 1)); if (p <= 0) continue;
    camTransform(rctx); rctx.save();
    rctx.beginPath(); rctx.rect(-1e4, -1e4, 2e4, 2e4); polyPathRaw(rctx, h); rctx.clip('evenodd');
    rctx.globalCompositeOperation = 'source-over';
    rctx.setLineDash([h.per * p, h.per]); rctx.strokeStyle = ACC; rctx.lineWidth = 2 * 7 / s; polyPathRaw(rctx, h); rctx.stroke();
    rctx.setLineDash([]); rctx.globalCompositeOperation = 'destination-out'; rctx.lineWidth = 2 * 5 / s; polyPathRaw(rctx, h); rctx.stroke();
    rctx.restore();
  }
  ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(ringCv, 0, 0); ctx.restore();
}
function polyPathRaw(c, h) { c.moveTo(h.pts[0][0], h.pts[0][1]); h.pts.slice(1).forEach(p => c.lineTo(p[0], p[1])); c.closePath(); }
function drawFlags(t) {
  ctx.save(); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  for (const h of S.holds) {
    if (!h.flagT0) continue;
    const p = spring((t - h.flagT0) / 1000, .45, .4); if (p <= 0) continue;
    const [sx, sy0] = toScreen(h.top[0], h.top[1]);
    const sy = sy0 - 3 - 20 * (1 - p), fh = 18;
    ctx.globalAlpha = clamp(p * 2, 0, 1);
    ctx.strokeStyle = ACC; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(sx, sy - fh); ctx.stroke();
    ctx.fillStyle = ACC; ctx.beginPath(); ctx.moveTo(sx, sy - fh); ctx.lineTo(sx + fh * .75, sy - fh * .78); ctx.lineTo(sx, sy - fh * .52); ctx.closePath(); ctx.fill();
  }
  ctx.restore();
}
function ripple(x, y, maxR = 120, color = '255,255,255', dur = 400) { S.ripples.push({ x, y, t0: now(), maxR, color, dur }); }
function drawRipples(t) {
  ctx.save(); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  S.ripples = S.ripples.filter(r => t - r.t0 < r.dur);
  for (const r of S.ripples) {
    if (S.reduce) continue;
    const p = easeOut((t - r.t0) / r.dur), [sx, sy] = toScreen(r.x, r.y);
    ctx.strokeStyle = `rgba(${r.color},${.6 * (1 - p)})`; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(sx, sy, 8 + (r.maxR - 8) * p, 0, Math.PI * 2); ctx.stroke();
  }
  ctx.restore();
}
function pulse(h, times = 3) { S.pulses.push({ h, t0: now(), times }); }
function drawPulses(t) {
  ctx.save(); camTransform(ctx);
  S.pulses = S.pulses.filter(p => t - p.t0 < p.times * 400 || S.reduce && t - p.t0 < 1600);
  for (const p of S.pulses) {
    const k = S.reduce ? 0 : ((t - p.t0) % 400) / 400, sc = 1 + k;
    ctx.strokeStyle = `rgba(255,115,97,${S.reduce ? .9 : 1 - k})`; ctx.lineWidth = 2.5 / S.cam.s;
    polyPath(ctx, p.h, sc); ctx.stroke();
  }
  ctx.restore();
}
function drawScan() {
  if (S.scanY == null) return;
  const [, sy] = toScreen(0, S.scanY), a = val(S, 'scanA');
  ctx.save(); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.globalCompositeOperation = 'lighter';
  const g = ctx.createLinearGradient(0, sy - 28, 0, sy + 28);
  g.addColorStop(0, 'rgba(255,230,150,0)'); g.addColorStop(.5, `rgba(255,236,170,${.28 * a})`); g.addColorStop(1, 'rgba(255,230,150,0)');
  ctx.fillStyle = g; ctx.fillRect(0, sy - 28, SW, 56);
  ctx.fillStyle = `rgba(255,248,220,${.7 * a})`; ctx.fillRect(0, sy - .5, SW, 1);
  ctx.restore();
}
