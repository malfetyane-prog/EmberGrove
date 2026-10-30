// Ember, drawn entirely in code. Mirrors Shared/EmberFigure.swift (200×200 design space).
import { FLAMES } from './content.js';

const BODY_TOP = '#FFF6E3', BODY_BOTTOM = '#F3C788', RIM = 'rgba(201,138,75,0.45)', EYE = '#2E2238';
const MOSS = '#6E9F4E', MOSS_DEEP = '#3F6B3A', MOSS_LIGHT = '#A9D46F', HONEY = '#E3A962', AMBER = '#F5A524', AMBER_GLOW = '#FFD27A';
const S = Math.sin, C = Math.cos, PI = Math.PI;

export function hexA(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

// ---------- Shape helpers (shared with the grove) ----------
export function flamePath(ctx, bx, by, w, h, sway) {
  const tx = bx + sway, ty = by - h;
  ctx.beginPath();
  ctx.moveTo(tx, ty);
  ctx.bezierCurveTo(bx + w * 0.15 + sway * 0.5, by - h * 0.75, bx + w / 2, by - h * 0.55, bx + w / 2, by - h * 0.3);
  ctx.bezierCurveTo(bx + w / 2, by + h * 0.06, bx - w / 2, by + h * 0.06, bx - w / 2, by - h * 0.3);
  ctx.bezierCurveTo(bx - w / 2, by - h * 0.55, bx - w * 0.15 + sway * 0.5, by - h * 0.75, tx, ty);
  ctx.closePath();
}
export function leafPath(ctx, bx, by, len, wid, angle) {
  ctx.save();
  ctx.translate(bx, by); ctx.rotate(angle);
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.quadraticCurveTo(len * 0.5, -wid, len, 0);
  ctx.quadraticCurveTo(len * 0.5, wid, 0, 0);
  ctx.closePath();
  ctx.restore();
}
export function fillLeaf(ctx, bx, by, len, wid, angle, color) {
  ctx.save(); ctx.translate(bx, by); ctx.rotate(angle);
  ctx.beginPath(); ctx.moveTo(0, 0);
  ctx.quadraticCurveTo(len * 0.5, -wid, len, 0); ctx.quadraticCurveTo(len * 0.5, wid, 0, 0);
  ctx.fillStyle = color; ctx.fill(); ctx.restore();
}
export function sparkle(ctx, x, y, r, color) {
  ctx.beginPath();
  ctx.moveTo(x, y - r);
  ctx.quadraticCurveTo(x, y, x + r, y); ctx.quadraticCurveTo(x, y, x, y + r);
  ctx.quadraticCurveTo(x, y, x - r, y); ctx.quadraticCurveTo(x, y, x, y - r);
  ctx.fillStyle = color; ctx.fill();
}
export function star(ctx, x, y, outer, inner, color, points = 5) {
  ctx.beginPath();
  for (let i = 0; i < points * 2; i++) {
    const r = i % 2 === 0 ? outer : inner, a = (i * PI) / points - PI / 2;
    const px = x + C(a) * r, py = y + S(a) * r;
    i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
  }
  ctx.closePath(); ctx.fillStyle = color; ctx.fill();
}
export function ellipse(ctx, x, y, rx, ry, color) {
  ctx.beginPath(); ctx.ellipse(x, y, Math.max(0.01, rx), Math.max(0.01, ry), 0, 0, PI * 2);
  ctx.fillStyle = color; ctx.fill();
}
export function flower(ctx, x, y, r, petal, center) {
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * PI * 2;
    ellipse(ctx, x + C(a) * r * 0.7, y + S(a) * r * 0.7, r * 0.55, r * 0.55, petal);
  }
  ellipse(ctx, x, y, r * 0.4, r * 0.4, center);
}
export function radialGlow(ctx, x, y, r, color, alpha) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, hexA(color, alpha)); g.addColorStop(1, hexA(color, 0));
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, PI * 2); ctx.fill();
}

function bodyPath(ctx, x, y, w, h) {
  ctx.beginPath();
  ctx.moveTo(x + w * 0.5, y);
  ctx.bezierCurveTo(x + w * 0.84, y, x + w, y + h * 0.28, x + w, y + h * 0.62);
  ctx.bezierCurveTo(x + w, y + h * 0.92, x + w * 0.8, y + h, x + w * 0.5, y + h);
  ctx.bezierCurveTo(x + w * 0.2, y + h, x, y + h * 0.92, x, y + h * 0.62);
  ctx.bezierCurveTo(x, y + h * 0.28, x + w * 0.16, y, x + w * 0.5, y);
  ctx.closePath();
}

function capPath(ctx, x, y, w, h) {
  const baseY = y + h * 0.3, left = x - 4, right = x + w + 4, seg = (right - left) / 5;
  ctx.beginPath();
  ctx.moveTo(left, y - 4); ctx.lineTo(right, y - 4); ctx.lineTo(right, baseY);
  for (let i = 0; i < 5; i++) {
    const x0 = right - i * seg, x1 = x0 - seg, depth = seg * (i % 2 === 0 ? 0.55 : 0.4);
    ctx.quadraticCurveTo((x0 + x1) / 2, baseY + depth, x1, baseY);
  }
  ctx.closePath();
}

/**
 * Draws Ember into a canvas context already scaled so that 200 units fit the target.
 * appearance: {stage, path, head, neck, face, flameTint}; mood: idle|happy|focused|sleepy|celebrating|curious
 */
export function drawEmber(ctx, a, mood, t, still) {
  const tint = FLAMES[a.flameTint] || FLAMES.amber;
  const stage = Math.max(0, Math.min(4, a.stage || 0));
  const scale = [0.72, 0.84, 0.92, 1.0, 1.06][stage];

  let bob = 0, breathe = S(t * 2.2), tilt = 0, hop = 0;
  if (mood === 'idle') bob = S(t * 1.6) * 2;
  if (mood === 'happy') { bob = S(t * 3) * 2.5; tilt = S(t * 1.5) * 0.04; }
  if (mood === 'focused') { bob = S(t * 0.9) * 1.2; breathe = S(t * 1.1); }
  if (mood === 'sleepy') { bob = S(t * 0.7); breathe = S(t * 0.8); tilt = 0.06; }
  if (mood === 'celebrating') hop = Math.abs(S(t * 4.5));
  if (mood === 'curious') tilt = S(t * 1.2) * 0.09;
  if (still) { bob = 0; hop = 0; breathe = 0; }

  const landing = mood === 'celebrating' && hop < 0.12 ? 0.05 : 0;
  const w = 104 * scale * (1 - breathe * 0.012 + landing);
  const h = 92 * scale * (1 + breathe * 0.018 + hop * 0.04);
  const groundY = 182, lift = hop * 18 - bob;
  const rx = 100 - w / 2, ry = groundY - 6 - h - lift, cx = 100;

  // shadow
  ellipse(ctx, 100, groundY - 0.5, w * (0.9 - hop * 0.3) / 2, 4.5, `rgba(46,34,56,${0.18 - hop * 0.08})`);

  // aura
  const flicker = still ? 0 : S(t * 7.3) * 0.5 + S(t * 11.1) * 0.5;
  radialGlow(ctx, cx, ry + h / 2 + h * 0.1, w * (0.95 + stage * 0.06) + flicker * 2, tint.glow, 0.32 + stage * 0.06);

  ctx.save();
  ctx.translate(cx, groundY - lift); ctx.rotate(tilt); ctx.translate(-cx, -(groundY - lift));

  // back layers
  if (a.path === 'starlight' && stage >= 2) drawWings(ctx, rx, ry, w, h, stage, tint, t, still);
  if (a.path === 'bloom' && stage >= 2) drawLeafEars(ctx, rx, ry, w, h, stage, t, still);
  if (a.path === 'hearth' && stage >= 3) drawTufts(ctx, rx, ry, w, h, tint, t, still);

  // feet & arms
  for (const sd of [-1, 1]) ellipse(ctx, cx + sd * w * 0.2, ry + h - 4 + 5 * scale, w * 0.11, 5 * scale, HONEY);
  let armRaise = 0;
  if (mood === 'celebrating') armRaise = -h * 0.28 * (0.5 + hop * 0.5);
  if (mood === 'happy') armRaise = -h * 0.08;
  for (const sd of [-1, 1]) ellipse(ctx, cx + sd * w * 0.49, ry + h * 0.66 + armRaise + 0.5 * scale, 7 * scale, 5.5 * scale, BODY_BOTTOM);

  // body
  const bg = ctx.createLinearGradient(0, ry, 0, ry + h);
  bg.addColorStop(0, BODY_TOP); bg.addColorStop(1, BODY_BOTTOM);
  bodyPath(ctx, rx, ry, w, h); ctx.fillStyle = bg; ctx.fill();

  ctx.save();
  bodyPath(ctx, rx, ry, w, h); ctx.clip();
  const bellyY = ry + h * 0.95, glowR = w * 0.42 + flicker * 1.5;
  radialGlow(ctx, cx, bellyY - glowR * 0.2, glowR, tint.glow, 0.95);
  const fh = h * (0.2 + stage * 0.018) * (1 + flicker * 0.06), fw = fh * 0.62;
  const sway = still ? 0 : S(t * 3.1) * 1.6;
  const fg = ctx.createLinearGradient(0, bellyY - fh, 0, bellyY);
  fg.addColorStop(0, tint.glow); fg.addColorStop(1, tint.core);
  flamePath(ctx, cx, bellyY - 2, fw, fh, sway); ctx.fillStyle = fg; ctx.fill();
  flamePath(ctx, cx, bellyY - 3, fw * 0.45, fh * 0.5, sway * 0.5); ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.fill();
  // moss cap
  const mg = ctx.createLinearGradient(0, ry, 0, ry + h * 0.36);
  mg.addColorStop(0, MOSS_LIGHT); mg.addColorStop(1, MOSS);
  capPath(ctx, rx, ry, w, h); ctx.fillStyle = mg; ctx.fill();
  for (const [dx, dy, r] of [[-0.28, 0.12, 0.05], [0.18, 0.08, 0.04], [0.33, 0.2, 0.03], [-0.08, 0.05, 0.03]]) {
    ellipse(ctx, cx + w * dx, ry + h * dy, w * r, w * r * 0.8, 'rgba(198,229,142,0.8)');
  }
  if (a.path === 'bloom' && stage >= 2) {
    [-0.3, 0.26, 0.05].forEach((dx, i) => {
      if (i < stage) flower(ctx, cx + w * dx, ry + h * (0.16 + (i % 2) * 0.06), 4.2 * scale, i === 1 ? '#FFD6E5' : '#FFFFFF', AMBER);
    });
  }
  ctx.restore();
  bodyPath(ctx, rx, ry, w, h); ctx.strokeStyle = RIM; ctx.lineWidth = 2; ctx.stroke();

  // face
  const eyeY = ry + h * 0.5, eyeDX = w * 0.18, ew = w * 0.115, eh = w * 0.145;
  drawEyes(ctx, mood, cx, eyeY, eyeDX, ew, eh, t, still);
  for (const sd of [-1, 1]) ellipse(ctx, cx + sd * w * 0.31, eyeY + eh * 0.55 + w * 0.035, w * 0.065, w * 0.035, 'rgba(255,143,143,0.42)');
  if (a.path === 'starlight' && stage >= 2) {
    for (const [sd, dy] of [[-1, 0], [1, 0.25], [-1, 0.45]]) {
      sparkle(ctx, cx + sd * w * (0.33 + dy * 0.05), eyeY + eh * (0.4 + dy * 1.2), 2.4 * scale, hexA(tint.core, 0.75));
    }
  }
  drawMouth(ctx, mood, cx, eyeY + eh * 0.95, scale);

  if (a.neck) drawNeck(ctx, a.neck, rx, ry, w, h, t, still);
  if (a.face === 'roundGlasses') {
    ctx.strokeStyle = '#5B4636'; ctx.lineWidth = 1.8;
    for (const sd of [-1, 1]) { ctx.beginPath(); ctx.arc(cx + sd * eyeDX, eyeY, ew * 1.25, 0, PI * 2); ctx.stroke(); }
    ctx.beginPath(); ctx.moveTo(cx - eyeDX + ew * 1.25, eyeY - 1);
    ctx.quadraticCurveTo(cx, eyeY - 4, cx + eyeDX - ew * 1.25, eyeY - 1); ctx.stroke();
  }

  const hatLift = !a.head ? 0 : a.head === 'mushroomHat' ? h * 0.2 : h * 0.12;
  drawTop(ctx, a, rx, ry, w, h, stage, tint, t, still, hatLift);
  if (a.head) drawHead(ctx, a.head, rx, ry, w, h);
  ctx.restore();

  drawParticles(ctx, a, mood, rx, ry, w, h, stage, tint, t, still);
}

function drawEyes(ctx, mood, cx, eyeY, dx, ew, eh, t, still) {
  ctx.lineCap = 'round';
  for (const sd of [-1, 1]) {
    const ex = cx + sd * dx;
    if (mood === 'happy' || mood === 'celebrating') {
      ctx.beginPath(); ctx.moveTo(ex - ew * 0.85, eyeY + eh * 0.25);
      ctx.quadraticCurveTo(ex, eyeY - eh * 0.95, ex + ew * 0.85, eyeY + eh * 0.25);
      ctx.strokeStyle = EYE; ctx.lineWidth = 3.2; ctx.stroke();
    } else if (mood === 'focused' || mood === 'sleepy') {
      ctx.beginPath(); ctx.moveTo(ex - ew * 0.8, eyeY);
      ctx.quadraticCurveTo(ex, eyeY + eh * 0.75, ex + ew * 0.8, eyeY);
      ctx.strokeStyle = EYE; ctx.lineWidth = 3; ctx.stroke();
    } else {
      const phase = (t + (sd > 0 ? 0.02 : 0)) % 4.3;
      const closed = !still && phase < 0.16 ? S((phase / 0.16) * PI) : 0;
      const boost = mood === 'curious' ? 1.12 : 1;
      const h2 = eh * boost * (1 - closed * 0.88), w2 = ew * boost;
      ellipse(ctx, ex, eyeY, w2, h2, EYE);
      if (closed < 0.5) {
        const look = mood === 'curious' ? S(t * 1.2) * w2 * 0.25 : 0;
        ellipse(ctx, ex + w2 * 0.12 + look, eyeY - h2 * 0.42, w2 * 0.36, w2 * 0.36, '#FFFFFF');
        ellipse(ctx, ex - w2 * 0.35 + look, eyeY + h2 * 0.35, w2 * 0.16, w2 * 0.16, 'rgba(255,255,255,0.85)');
      }
    }
  }
}

function drawMouth(ctx, mood, cx, y, sc) {
  if (mood === 'happy' || mood === 'celebrating') {
    ctx.beginPath(); ctx.moveTo(cx - 6 * sc, y - 1);
    ctx.quadraticCurveTo(cx, y + 10 * sc, cx + 6 * sc, y - 1); ctx.closePath();
    ctx.fillStyle = EYE; ctx.fill();
    ellipse(ctx, cx, y + 3.5 * sc, 3 * sc, 1.5 * sc, '#FF7E8B');
  } else if (mood === 'sleepy') {
    ctx.beginPath(); ctx.arc(cx, y + 2.5 * sc, 2.5 * sc, 0, PI * 2); ctx.strokeStyle = EYE; ctx.lineWidth = 2; ctx.stroke();
  } else if (mood === 'curious') {
    ellipse(ctx, cx, y + 2 * sc, 2.5 * sc, 2 * sc, EYE);
  } else {
    ctx.beginPath(); ctx.moveTo(cx - 5 * sc, y);
    ctx.quadraticCurveTo(cx, y + 5 * sc, cx + 5 * sc, y);
    ctx.strokeStyle = EYE; ctx.lineWidth = 2.2; ctx.lineCap = 'round'; ctx.stroke();
  }
}

function drawTop(ctx, a, rx, ry, w, h, stage, tint, t, still, lift) {
  const tx = rx + w / 2, ty = ry + 3 - lift;
  const sway = still ? 0 : S(t * 1.8) * 0.12;
  const path = stage >= 2 ? a.path : null;
  ctx.lineCap = 'round';
  if (path === 'hearth') {
    const fh = 22 + stage * 5, fl = still ? 0 : S(t * 6.1) * 1.5;
    const g = ctx.createLinearGradient(0, ty - fh, 0, ty);
    g.addColorStop(0, tint.glow); g.addColorStop(1, tint.core);
    flamePath(ctx, tx, ty, fh * 0.62, fh + fl, fl); ctx.fillStyle = g; ctx.fill();
    flamePath(ctx, tx, ty - 1, fh * 0.28, fh * 0.5, fl * 0.5); ctx.fillStyle = 'rgba(255,255,255,0.8)'; ctx.fill();
  } else if (path === 'starlight') {
    for (const sd of [-1, 1]) {
      const ex = tx + sd * (18 + stage * 3), ey = ty - 20 - stage * 3;
      ctx.beginPath(); ctx.moveTo(tx + sd * 6, ty + 2); ctx.quadraticCurveTo(tx + sd * 2, ty - 18, ex, ey);
      ctx.strokeStyle = '#6B5A8E'; ctx.lineWidth = 2; ctx.stroke();
      const tw = still ? 1 : 0.75 + 0.25 * S(t * 3 + sd);
      sparkle(ctx, ex, ey, 5.5 * tw, tint.glow);
      ellipse(ctx, ex, ey, 2, 2, '#FFFFFF');
    }
  } else if (path === 'bloom') {
    const tipX = tx + sway * 30, tipY = ty - 18 - stage * 2;
    ctx.beginPath(); ctx.moveTo(tx, ty); ctx.quadraticCurveTo(tx - 4, ty - 10, tipX, tipY);
    ctx.strokeStyle = MOSS_DEEP; ctx.lineWidth = 2.4; ctx.stroke();
    fillLeaf(ctx, tx - 1, ty - 7, 12, 5, -2.6, MOSS);
    flower(ctx, tipX, tipY, 5 + stage * 1.4, '#FFB7CF', AMBER_GLOW);
  } else if (!a.head) {
    const len = 10 + stage * 4, tipX = tx + sway * 20, tipY = ty - len;
    ctx.beginPath(); ctx.moveTo(tx, ty); ctx.quadraticCurveTo(tx - 2, ty - len * 0.5, tipX, tipY);
    ctx.strokeStyle = MOSS_DEEP; ctx.lineWidth = 2.4; ctx.stroke();
    fillLeaf(ctx, tipX, tipY, 11 + stage * 2, 5.5, -2.5 + sway, MOSS);
    fillLeaf(ctx, tipX, tipY, 13 + stage * 2, 6, -0.5 + sway, MOSS_LIGHT);
  }
}

function drawWings(ctx, rx, ry, w, h, stage, tint, t, still) {
  const flutter = still ? 0 : S(t * 5) * 0.12;
  const size = w * (0.38 + (stage - 2) * 0.07);
  for (const sd of [-1, 1]) {
    const ax = rx + w / 2 + sd * w * 0.32, ay = ry + h * 0.42;
    [[size, -0.55], [size * 0.72, 0.35]].forEach(([len, ang], i) => {
      const angle = sd > 0 ? ang - flutter : PI - ang + flutter;
      ctx.save(); ctx.translate(ax, ay); ctx.rotate(angle);
      ctx.beginPath(); ctx.ellipse(len / 2, 0, len / 2, len * 0.33, 0, 0, PI * 2);
      ctx.fillStyle = hexA(tint.glow, i === 0 ? 0.55 : 0.45); ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,0.75)'; ctx.lineWidth = 1.2; ctx.stroke();
      ctx.restore();
    });
  }
}

function drawLeafEars(ctx, rx, ry, w, h, stage, t, still) {
  const wig = still ? 0 : S(t * 1.4) * 0.06, len = w * (0.3 + (stage - 2) * 0.05);
  for (const sd of [-1, 1]) {
    const bx = rx + w / 2 + sd * w * 0.36, by = ry + h * 0.18;
    const ang = sd > 0 ? -0.45 + wig : PI + 0.45 - wig;
    fillLeaf(ctx, bx, by, len, len * 0.42, ang, MOSS);
    ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx + C(ang) * len * 0.8, by + S(ang) * len * 0.8);
    ctx.strokeStyle = 'rgba(63,107,58,0.6)'; ctx.lineWidth = 1; ctx.stroke();
  }
}

function drawTufts(ctx, rx, ry, w, h, tint, t, still) {
  for (const sd of [-1, 1]) {
    const fl = still ? 0 : S(t * 7 + sd) * 1.2;
    ctx.save(); ctx.translate(rx + w / 2 + sd * w * 0.34, ry + h * 0.2); ctx.rotate(sd * 0.6);
    flamePath(ctx, 0, 0, 12, 20 + fl, fl); ctx.fillStyle = hexA(tint.core, 0.9); ctx.fill();
    ctx.restore();
  }
}

function drawHead(ctx, id, rx, ry, w, h) {
  const cx = rx + w / 2, top = ry;
  if (id === 'acornCap') {
    const x0 = cx - w * 0.24, x1 = cx + w * 0.24, y0 = top - w * 0.07, y1 = y0 + w * 0.2;
    ctx.beginPath(); ctx.moveTo(x0, y1);
    ctx.quadraticCurveTo(cx, y0 - w * 0.12, x1, y1); ctx.quadraticCurveTo(cx, y1 + w * 0.05, x0, y1);
    ctx.fillStyle = '#9A6233'; ctx.fill();
    ctx.strokeStyle = 'rgba(196,138,82,0.7)'; ctx.lineWidth = 1.2;
    for (let i = 0; i < 4; i++) {
      const x = x0 + (x1 - x0) * (0.2 + i * 0.2);
      ctx.beginPath(); ctx.moveTo(x - 4, y1 - 1); ctx.lineTo(x + 3, y0 + 3); ctx.stroke();
    }
    ctx.fillStyle = '#6E4422'; ctx.fillRect(cx - 2, y0 - w * 0.08, 4, w * 0.08);
  } else if (id === 'mushroomHat') {
    const x0 = cx - w * 0.36, x1 = cx + w * 0.36, y0 = top - w * 0.2, y1 = y0 + w * 0.36;
    const g = ctx.createLinearGradient(0, y0, 0, y1); g.addColorStop(0, '#F07167'); g.addColorStop(1, '#C94A47');
    ctx.beginPath(); ctx.moveTo(x0, y1);
    ctx.bezierCurveTo(x0, y0 - 6, x1, y0 - 6, x1, y1); ctx.quadraticCurveTo(cx, y1 + 6, x0, y1);
    ctx.fillStyle = g; ctx.fill();
    for (const [dx, dy, r] of [[-0.2, 0.45, 0.06], [0.12, 0.3, 0.07], [0.26, 0.62, 0.045], [-0.02, 0.68, 0.04]]) {
      ellipse(ctx, cx + w * dx, y0 + (y1 - y0) * dy, w * r, w * r * 0.8, '#FFF4E0');
    }
  } else if (id === 'flowerCrown') {
    const colors = ['#FFB7CF', '#FFFFFF', '#FFD27A', '#B9A6E0', '#FFB7CF'];
    colors.forEach((col, i) => {
      const f = i / (colors.length - 1), x = cx - w * 0.36 + f * w * 0.72, y = top + h * 0.14 - S(f * PI) * h * 0.12;
      fillLeaf(ctx, x, y, 7, 3, -1.2 + f * 2.4, MOSS_DEEP);
      flower(ctx, x, y, 4.6, col, AMBER);
    });
  } else if (id === 'starCirclet') {
    ctx.beginPath(); ctx.moveTo(cx - w * 0.38, top + h * 0.3);
    ctx.quadraticCurveTo(cx, top + h * 0.12, cx + w * 0.38, top + h * 0.3);
    ctx.strokeStyle = '#F2C14E'; ctx.lineWidth = 2.4; ctx.lineCap = 'round'; ctx.stroke();
    star(ctx, cx, top + h * 0.2, 7, 3.2, '#FFE07A');
  }
}

function drawNeck(ctx, id, rx, ry, w, h, t, still) {
  const cx = rx + w / 2, y = ry + h * 0.72, bh = h * 0.085, half = w * 0.485;
  const sway = still ? 0 : S(t * 1.7) * 0.08;
  const band = () => {
    ctx.beginPath(); ctx.moveTo(cx - half, y);
    ctx.quadraticCurveTo(cx, y + bh * 0.9, cx + half, y);
    ctx.lineTo(cx + half * 0.98, y + bh);
    ctx.quadraticCurveTo(cx, y + bh * 1.9, cx - half * 0.98, y + bh); ctx.closePath();
  };
  if (id === 'leafScarf') {
    band(); ctx.fillStyle = MOSS; ctx.fill();
    fillLeaf(ctx, cx + half * 0.55, y + bh, w * 0.2, w * 0.08, 1.3 + sway, MOSS_LIGHT);
    fillLeaf(ctx, cx + half * 0.55, y + bh, w * 0.17, w * 0.07, 1.85 + sway, MOSS);
  } else if (id === 'knitScarf') {
    band(); ctx.fillStyle = '#E8674A'; ctx.fill();
    ctx.setLineDash([2, 3]); ctx.strokeStyle = 'rgba(255,214,194,0.7)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.save(); ctx.translate(cx + half * 0.45, y + bh * 0.6); ctx.rotate(-0.15 + sway);
    ctx.fillStyle = '#D45539'; ctx.fillRect(0, 0, w * 0.1, h * 0.3); ctx.strokeRect(0, 0, w * 0.1, h * 0.3);
    ctx.restore(); ctx.setLineDash([]);
  } else if (id === 'bellCollar') {
    ctx.beginPath(); ctx.moveTo(cx - half, y + bh * 0.3);
    ctx.quadraticCurveTo(cx, y + bh * 1.4, cx + half, y + bh * 0.3);
    ctx.strokeStyle = '#4F7CAC'; ctx.lineWidth = 3.2; ctx.lineCap = 'round'; ctx.stroke();
    ellipse(ctx, cx, y + bh * 1.3 + 1, 5, 5, '#F2C14E');
    ctx.beginPath(); ctx.moveTo(cx, y + bh * 1.3 + 1.5); ctx.lineTo(cx, y + bh * 1.3 + 5);
    ctx.strokeStyle = '#8A6420'; ctx.lineWidth = 1.2; ctx.stroke();
  }
}

function drawParticles(ctx, a, mood, rx, ry, w, h, stage, tint, t, still) {
  const cx = rx + w / 2, cy = ry + h / 2;
  if (mood === 'celebrating') {
    for (let i = 0; i < 7; i++) {
      const ang = (i / 7) * PI * 2 + t * 0.8, r = w * 0.8 + S(t * 3 + i) * 6;
      const tw = 0.5 + 0.5 * S(t * 6 + i * 1.7);
      sparkle(ctx, cx + C(ang) * r, cy + S(ang) * r * 0.75, 3 + 4 * tw, i % 2 === 0 ? tint.glow : '#FFFFFF');
    }
  }
  if (mood === 'sleepy' && !still) {
    ctx.fillStyle = '#B9A6E0'; ctx.textAlign = 'center';
    for (let i = 0; i < 3; i++) {
      const ph = (t * 0.35 + i / 3) % 1;
      ctx.globalAlpha = 1 - ph;
      ctx.font = `bold ${10 + ph * 8}px ui-rounded, system-ui, sans-serif`;
      ctx.fillText('z', cx + w * 0.4 + ph * 18, ry - ph * 36);
    }
    ctx.globalAlpha = 1;
  }
  if (stage < 3 || !a.path || still) return;
  const count = stage === 4 ? 6 : 3;
  if (a.path === 'hearth') {
    for (let i = 0; i < count; i++) {
      const ph = (t * 0.4 + i / count) % 1;
      ellipse(ctx, cx + S(i * 2.4 + t) * w * 0.5, ry + h - ph * h * 1.6, 2, 2, hexA(tint.core, 1 - ph));
    }
  } else if (a.path === 'bloom') {
    for (let i = 0; i < Math.floor(count / 3) + 1; i++) {
      const ang = t * 0.9 + i * PI, px = cx + C(ang) * w * 0.75, py = cy - 20 + S(ang * 2) * 14;
      const flap = Math.abs(S(t * 12 + i)), col = i === 0 ? '#FFB7CF' : AMBER_GLOW;
      ellipse(ctx, px + 3 * flap, py, 3 * flap, 4, col);
      ellipse(ctx, px - 3 * flap, py, 3 * flap, 4, col);
    }
  } else if (a.path === 'starlight') {
    for (let i = 0; i < count; i++) {
      const ang = t * 0.5 + (i / count) * PI * 2;
      sparkle(ctx, cx + C(ang) * w * 0.72, cy + S(ang) * h * 0.35 - 10, 3.5, tint.glow);
    }
  }
}
