// The grove, drawn in code. World space is 1600 × 600. Mirrors GroveScene.swift.
import { LANDMARKS, AREAS } from './content.js';
import { flamePath, fillLeaf, sparkle, star, ellipse, flower, radialGlow, hexA } from './ember.js';
import { seeded } from './game.js';

export const WORLD_W = 1600, WORLD_H = 600;
const S = Math.sin, C = Math.cos, PI = Math.PI;

export function skyPhase(date = new Date()) {
  const h = date.getHours();
  return h >= 6 && h < 17 ? 'day' : h >= 17 && h < 20 ? 'dusk' : 'night';
}

const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
export const groundY = (x) => 430 + S(x / 140) * 8 + S(x / 61) * 3 - smooth(1170, 1360, x) * 48;
const farHill = (x) => 300 + S(x / 130) * 28 + S(x / 53 + 2) * 10 - smooth(1100, 1500, x) * 40;
const midHill = (x) => 365 + S(x / 170 + 1) * 22 + S(x / 71) * 8 - smooth(1150, 1400, x) * 40;

const rgb = (hex) => { const n = parseInt(hex.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const mix = (a, b, f) => { const x = rgb(a), y = rgb(b); return `rgb(${x.map((v, i) => Math.round(v + (y[i] - v) * f)).join(',')})`; };
const mixHex = (a, b, f) => { const x = rgb(a), y = rgb(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * f).toString(16).padStart(2, '0')).join(''); };

/** snap: {restored, unlockedAreas, decorations, companions, hearthLit, curios} */
export function drawGrove(ctx, snap, { phase, viewport = [0, WORLD_W], t = 0, still = false, hearthBoost = 0 }) {
  const R = new Renderer(ctx, snap, phase, viewport, t, still, hearthBoost);
  R.draw();
}

class Renderer {
  constructor(ctx, snap, phase, viewport, t, still, boost) {
    Object.assign(this, { ctx, snap, phase, vp: viewport, t, still, boost });
    this.dark = phase !== 'day';
    this.vitality = Object.keys(snap.restored).length / LANDMARKS.length;
  }

  fill(path, color) { this.ctx.fillStyle = color; this.ctx.fill(path); }
  el(x, y, rx, ry, color) { ellipse(this.ctx, x, y, rx, ry, color); }
  glow(x, y, r, color, a) { radialGlow(this.ctx, x, y, r, color, a); }
  areaOf(x) { return (AREAS.find((a) => x >= a.xStart && x < a.xEnd) || AREAS[0]).id; }
  areaVitality(id) {
    const ls = LANDMARKS.filter((l) => l.area === id);
    return ls.filter((l) => this.snap.restored[l.id]).length / ls.length;
  }

  draw() {
    this.sky(); this.hills(); this.trees(); this.ground();
    if (this.snap.unlockedAreas.includes('brook')) this.brook();
    this.path();
    const items = [];
    for (const l of LANDMARKS) {
      if (!this.snap.unlockedAreas.includes(l.area)) continue;
      if (l.requiresCurio && !this.snap.curios[l.requiresCurio]) continue;
      if (l.requiresLandmark && !this.snap.restored[l.requiresLandmark]) continue;
      const variant = this.snap.restored[l.id];
      const color = (l.variants.find((v) => v.id === variant) || l.variants[0]).color;
      items.push([l.y, () => this.landmark(l.id, l.x, l.y, !!variant, color, variant)]);
    }
    items.push([455, () => this.hearth(260, 455)]);
    for (const d of this.snap.decorations) items.push([decorDepth[d] ?? 445, () => this.decoration(d)]);
    for (const c of this.snap.companions) items.push([companionDepth[c] ?? 450, () => this.companion(c)]);
    items.sort((a, b) => a[0] - b[0]).forEach((i) => i[1]());
    this.fireflies();
    if (this.vitality < 0.34) this.frost();
    this.fog();
  }

  sky() {
    const { ctx } = this;
    const [top, bottom] = { day: ['#9ED2F2', '#FFEBC9'], dusk: ['#3B2C5A', '#F4A877'], night: ['#110C22', '#3A2B5C'] }[this.phase];
    const g = ctx.createLinearGradient(0, 0, 0, 420); g.addColorStop(0, top); g.addColorStop(1, bottom);
    ctx.fillStyle = g; ctx.fillRect(this.vp[0] - 2, 0, this.vp[1] - this.vp[0] + 4, 600);
    if (this.phase !== 'day') {
      const rnd = seeded(7);
      for (let i = 0; i < 90; i++) {
        const x = rnd() * 1600, y = 10 + rnd() * 250, r = 0.6 + rnd() * 1.2;
        const tw = this.still ? 0.8 : 0.55 + 0.45 * S(this.t * (0.8 + (i % 7) * 0.3) + i);
        this.el(x, y, r, r, `rgba(255,255,255,${(this.phase === 'night' ? 0.9 : 0.45) * tw})`);
      }
      this.glow(430, 90, 70, '#FFF1C9', this.phase === 'night' ? 0.35 : 0.2);
      this.el(430, 90, 22, 22, '#FFF4D6');
      this.el(440, 84, 19, 19, this.phase === 'night' ? 'rgba(26,19,48,0.92)' : 'rgba(74,55,104,0.92)');
    } else {
      this.glow(430, 95, 90, '#FFE7A0', 0.5);
      this.el(430, 95, 26, 26, '#FFE7A0');
      for (const [cx, cy, s] of [[160, 110, 1], [760, 70, 0.8], [1180, 120, 1.1], [1450, 80, 0.7]]) {
        const d = this.still ? 0 : S(this.t * 0.05 + cx) * 12;
        for (const [dx, dy, r] of [[-26, 6, 20], [0, 0, 28], [28, 6, 20], [10, 12, 18]]) {
          this.el(cx + d + dx * s, cy + dy * s, r * s, r * s * 0.7, 'rgba(255,255,255,0.85)');
        }
      }
    }
  }

  wave(fn) {
    const p = new Path2D(), x0 = this.vp[0] - 20, x1 = this.vp[1] + 20;
    p.moveTo(x0, 600);
    for (let x = x0; x <= x1; x += 12) p.lineTo(x, fn(x));
    p.lineTo(x1, 600); p.closePath();
    return p;
  }

  hills() {
    const d = this.dark, v = this.vitality;
    this.fill(this.wave(farHill), mix(d ? '#4B3B72' : '#B9B4DE', d ? '#3E3C70' : '#A7C6D9', v));
    this.fill(this.wave(midHill), mix(d ? '#34405A' : '#A9B7A6', d ? '#2F4A4A' : '#8DBB72', v));
  }

  trees() {
    const list = [[30, 398, 62], [175, 388, 48], [340, 392, 56], [470, 396, 70], [560, 388, 60], [690, 384, 48],
      [930, 390, 64], [990, 380, 44], [1190, 380, 58], [1270, 372, 46], [1420, 352, 40], [1590, 350, 52]];
    for (const [x, y, r] of list) {
      if (x < this.vp[0] - 90 || x > this.vp[1] + 90) continue;
      const area = this.areaOf(x), unlocked = this.snap.unlockedAreas.includes(area), v = this.areaVitality(area);
      const canopy = mix(this.dark ? '#4E4766' : '#9B97A8', this.dark ? '#2E5A45' : '#5E9A4A', unlocked ? 0.25 + v * 0.75 : 0.1);
      this.ctx.fillStyle = this.dark ? '#3A2C3E' : '#7A5A44';
      this.ctx.fillRect(x - r * 0.09, y - r * 0.4, r * 0.18, r * 0.6);
      const sw = this.still ? 0 : S(this.t * 0.6 + x) * 1.5;
      for (const [dx, dy, rr] of [[-0.45, -0.55, 0.55], [0.45, -0.55, 0.55], [0, -0.95, 0.65], [0, -0.5, 0.6]]) {
        this.el(x + r * dx + sw, y + r * dy, r * rr, r * rr * 0.9, canopy);
      }
      if (!unlocked || v === 0) this.el(x + sw, y - r * 1.25, r * 0.5, r * 0.18, 'rgba(244,246,255,0.75)');
    }
  }

  ground() {
    const { ctx } = this;
    const top = mixHex(this.dark ? '#4A5A63' : '#B8C6C3', this.dark ? '#2F5A3C' : '#7DB356', 0.2 + this.vitality * 0.8);
    const bottom = mix(top, this.dark ? '#152519' : '#4C8A3A', 0.6);
    const g = ctx.createLinearGradient(0, 380, 0, 600); g.addColorStop(0, top); g.addColorStop(1, bottom);
    ctx.fillStyle = g; ctx.fill(this.wave(groundY));
    const rnd = seeded(21);
    ctx.strokeStyle = hexA(this.dark ? '#2F5A3C' : '#4E8A3A', 0.35 + this.vitality * 0.5); ctx.lineWidth = 1.4;
    for (let i = 0; i < 70; i++) {
      const x = rnd() * 1600, y = groundY(x) + 15 + rnd() * 135;
      if (x < this.vp[0] - 10 || x > this.vp[1] + 10) continue;
      ctx.beginPath();
      for (const dx of [-3, 0, 3]) { ctx.moveTo(x + dx, y); ctx.lineTo(x + dx * 1.6, y - 7); }
      ctx.stroke();
    }
  }

  brook() {
    const { ctx } = this;
    const alive = ['lilyPond', 'willowBridge', 'waterWheel'].some((id) => this.snap.restored[id]);
    ctx.beginPath(); ctx.moveTo(700, groundY(700) - 2);
    ctx.bezierCurveTo(690, 480, 800, 520, 760, 600);
    ctx.lineCap = 'round'; ctx.lineWidth = 34;
    ctx.strokeStyle = alive ? (this.dark ? '#3E6E9E' : '#6FB6E0') : '#CFE0E8'; ctx.stroke();
    ctx.setLineDash([10, 22]); ctx.lineDashOffset = alive && !this.still ? -this.t * 30 : 0;
    ctx.lineWidth = 2; ctx.strokeStyle = `rgba(255,255,255,${alive ? 0.35 : 0.6})`; ctx.stroke();
    ctx.setLineDash([]);
  }

  path() {
    const { ctx } = this;
    ctx.beginPath(); ctx.moveTo(-20, 498);
    ctx.bezierCurveTo(150, 470, 350, 535, 520, 505);
    ctx.bezierCurveTo(800, 470, 1000, 520, 1260, 490);
    ctx.bezierCurveTo(1400, 470, 1500, 440, 1620, 450);
    ctx.strokeStyle = hexA(this.dark ? '#5A4A52' : '#D9BE8C', 0.55); ctx.lineWidth = 22; ctx.lineCap = 'round'; ctx.stroke();
  }

  hearth(x, y) {
    const { ctx } = this, lit = this.snap.hearthLit;
    if (lit) {
      const strength = 0.35 + this.boost * 0.35 + this.vitality * 0.2;
      this.glow(x, y - 20, 140 + this.boost * 40, '#FFB347', this.dark ? strength : strength * 0.5);
    }
    for (let i = 0; i < 9; i++) { const a = (i / 9) * PI; this.el(x + C(a) * 34, y + 4 + S(a) * 9, 9, 6.5, this.dark ? '#6D6577' : '#9C96A0'); }
    for (const [ang, col] of [[0.25, '#7A4A2A'], [-0.25, '#8B5A33']]) {
      ctx.save(); ctx.translate(x, y); ctx.rotate(ang); ctx.fillStyle = col;
      ctx.beginPath(); ctx.roundRect(-26, -5, 52, 10, 5); ctx.fill(); ctx.restore();
    }
    if (!lit) { this.el(x, y - 2, 14, 4, 'rgba(90,85,96,0.7)'); return; }
    const size = 1 + this.boost * 0.35 + this.vitality * 0.3;
    [[-8, '#E8674A'], [8, '#E8674A'], [0, '#FF9A1F'], [0, '#FFD27A']].forEach(([dx, col], i) => {
      const h = (i < 2 ? 30 : i === 2 ? 44 : 26) * size;
      const fl = this.still ? 0 : S(this.t * (6 + i) + i) * 3;
      flamePath(ctx, x + dx, y - 2, h * 0.55, h + fl, fl); ctx.fillStyle = col; ctx.fill();
    });
    if (!this.still) {
      for (let i = 0; i < 5; i++) {
        const ph = (this.t * 0.6 + i / 5) % 1;
        this.el(x + S(i * 2.1 + this.t) * 14, y - 30 - ph * 70, 1.6, 1.6, `rgba(255,210,122,${1 - ph})`);
      }
    }
  }

  landmark(id, x, y, alive, color, variant) {
    const { ctx, t, still, dark } = this;
    const dead = dark ? '#5B566A' : '#9E99A8';
    if (!alive && !still) {
      const tw = 0.5 + 0.5 * S(t * 2 + x);
      sparkle(ctx, x + 18, y - 60, 5 + 3 * tw, `rgba(255,231,160,${0.4 + 0.5 * tw})`);
    }
    ctx.lineCap = 'round';
    switch (id) {
      case 'mushroomRing':
        for (let i = 0; i < 6; i++) {
          const a = (i / 6) * PI * 2, mx = x + C(a) * 46, my = y + S(a) * 12, s = alive ? 0.8 + (i % 3) * 0.15 : 0.45;
          ctx.fillStyle = alive ? '#FFF1DC' : dead; ctx.beginPath(); ctx.roundRect(mx - 4 * s, my - 16 * s, 8 * s, 16 * s, 3); ctx.fill();
          ctx.beginPath(); ctx.moveTo(mx - 13 * s, my - 14 * s); ctx.quadraticCurveTo(mx, my - 38 * s, mx + 13 * s, my - 14 * s); ctx.closePath();
          ctx.fillStyle = alive ? color : dead; ctx.fill();
          if (alive) {
            this.el(mx - 4 * s, my - 21 * s, 2.5 * s, 2 * s, '#FFF4E0'); this.el(mx + 5 * s, my - 19 * s, 2 * s, 1.6 * s, '#FFF4E0');
            if (variant === 'glowcap' && dark) this.glow(mx, my - 20 * s, 22, color, 0.45);
          }
        }
        break;
      case 'meadow': {
        const rnd = seeded(99);
        for (let i = 0; i < 26; i++) {
          const fx = x - 80 + rnd() * 165, fy = y - 10 + rnd() * 44, h = 16 + rnd() * 14;
          const sw = still ? 0 : S(t * 1.3 + fx * 0.1) * 2.5;
          ctx.beginPath(); ctx.moveTo(fx, fy); ctx.quadraticCurveTo(fx, fy - h * 0.5, fx + sw, fy - h);
          ctx.strokeStyle = alive ? '#4E8A3A' : '#8C8577'; ctx.lineWidth = 1.6; ctx.stroke();
          if (!alive) continue;
          const hx = fx + sw, hy = fy - h;
          if (variant === 'bluebells') { for (let k = 0; k < 3; k++) this.el(hx + 3 + k * 1.5, hy + k * 5, 2.6, 3.4, color); }
          else {
            for (let k = 0; k < 8; k++) { const a = (k / 8) * PI * 2; this.el(hx + C(a) * 4.5, hy + S(a) * 4.5, 2.8, 2.8, color); }
            this.el(hx, hy, 3, 3, '#7A4A2A');
          }
        }
        if (alive && !still) {
          for (let i = 0; i < 2; i++) {
            const a = t * 0.9 + i * 3, bx = x + C(a) * 60, by = y - 30 + S(a * 2) * 10;
            this.el(bx, by, 3.5, 2.6, '#F7C548'); this.el(bx, by - 3, 2.5, 1.6, 'rgba(255,255,255,0.8)');
          }
        }
        break;
      }
      case 'stoneLanterns':
        for (const lx of [x, 500]) {
          const ly = lx === x ? y : 438, stone = dark ? '#7A7285' : '#B2ACBA';
          ctx.fillStyle = dark ? '#6D6577' : '#A19BAA'; ctx.fillRect(lx - 12, ly - 8, 24, 8);
          ctx.fillStyle = stone; ctx.fillRect(lx - 5, ly - 30, 10, 22);
          ctx.beginPath(); ctx.roundRect(lx - 11, ly - 50, 22, 20, 3); ctx.fill();
          ctx.fillStyle = alive ? color : '#3B3446'; ctx.fillRect(lx - 6, ly - 46, 12, 12);
          ctx.beginPath(); ctx.moveTo(lx - 17, ly - 50); ctx.quadraticCurveTo(lx, ly - 70, lx + 17, ly - 50); ctx.closePath();
          ctx.fillStyle = dark ? '#5E5770' : '#8F889C'; ctx.fill();
          if (alive) this.glow(lx, ly - 40, 46, color, dark ? 0.55 : 0.25);
          else this.el(lx - 6, ly - 52, 9, 3, 'rgba(125,179,86,0.7)');
        }
        break;
      case 'lilyPond':
        this.el(x, y, 62, 18, alive ? (dark ? '#2E5B82' : '#6BB3D9') : '#8D8A82');
        this.el(x, y - 2, 56, 13, alive ? (dark ? 'rgba(60,110,152,0.8)' : 'rgba(141,203,234,0.8)') : 'rgba(156,153,143,0.8)');
        if (alive) {
          for (const [dx, dy] of [[-30, 2], [12, -4], [32, 4]]) {
            ctx.beginPath(); ctx.ellipse(x + dx, y + dy, 11, 4, 0, 0.35, PI * 2 - 0.05); ctx.lineTo(x + dx, y + dy); ctx.closePath();
            ctx.fillStyle = '#4E8A3A'; ctx.fill();
          }
          flower(ctx, x - 28, y - 1, 4, color, '#FFD27A'); flower(ctx, x + 33, y + 2, 3.4, color, '#FFD27A');
          if (!still) {
            const r = (t * 0.4) % 1;
            ctx.beginPath(); ctx.ellipse(x + 5, y, 8 + r * 30, 2 + r * 7, 0, 0, PI * 2);
            ctx.strokeStyle = `rgba(255,255,255,${0.5 * (1 - r)})`; ctx.lineWidth = 1; ctx.stroke();
          }
        } else {
          ctx.strokeStyle = '#8C7F6A'; ctx.lineWidth = 1.5;
          for (const dx of [-50, -42, 44, 52]) { ctx.beginPath(); ctx.moveTo(x + dx, y); ctx.lineTo(x + dx + 4, y - 26); ctx.stroke(); }
        }
        break;
      case 'willowBridge': {
        const wood = alive ? color : dead;
        if (alive) {
          ctx.beginPath(); ctx.moveTo(x - 50, y + 8); ctx.quadraticCurveTo(x, y - 34, x + 50, y + 8);
          ctx.strokeStyle = wood; ctx.lineWidth = 9; ctx.stroke();
          ctx.beginPath(); ctx.moveTo(x - 46, y - 8); ctx.quadraticCurveTo(x, y - 50, x + 46, y - 8);
          ctx.lineWidth = 3; ctx.stroke();
          ctx.lineWidth = 2;
          for (let px = -40; px <= 40; px += 16) {
            const ay = y + 8 - 21 * (1 - (px / 50) ** 2);
            ctx.beginPath(); ctx.moveTo(x + px, ay); ctx.lineTo(x + px, ay - 15); ctx.stroke();
          }
          if (variant === 'willow') for (const px of [-30, 0, 28]) fillLeaf(ctx, x + px, y - 22, 10, 4, 1.4, '#9CCB6E');
        } else {
          ctx.strokeStyle = wood; ctx.lineWidth = 8;
          for (const sd of [-1, 1]) { ctx.beginPath(); ctx.moveTo(x + sd * 50, y + 8); ctx.lineTo(x + sd * 18, y - 6); ctx.stroke(); }
        }
        break;
      }
      case 'waterWheel': {
        const wx = x - 30, wy = y - 22;
        ctx.fillStyle = alive ? '#F1DFC0' : dead; ctx.beginPath(); ctx.roundRect(x - 16, y - 50, 46, 50, 3); ctx.fill();
        ctx.beginPath(); ctx.moveTo(x - 24, y - 48); ctx.lineTo(x + 7, y - 76); ctx.lineTo(x + 38, y - 48); ctx.closePath();
        ctx.fillStyle = alive ? color : '#6E6878'; ctx.fill();
        ctx.fillStyle = alive && dark ? '#FFD27A' : '#5A4A52'; ctx.fillRect(x + 2, y - 30, 12, 14);
        const spin = alive && !still ? t * 0.8 : 0.3, wood = alive ? '#8B5A33' : '#6E6878';
        ctx.beginPath(); ctx.arc(wx, wy, 22, 0, PI * 2); ctx.strokeStyle = wood; ctx.lineWidth = 4; ctx.stroke();
        ctx.lineWidth = 2.5;
        for (let k = 0; k < 8; k++) {
          const a = spin + (k / 8) * PI * 2;
          ctx.beginPath(); ctx.moveTo(wx, wy); ctx.lineTo(wx + C(a) * 24, wy + S(a) * 24); ctx.stroke();
        }
        break;
      }
      case 'oldOak': {
        const bark = dark ? '#4A3530' : '#7A5236';
        ctx.beginPath(); ctx.moveTo(x - 34, y);
        ctx.bezierCurveTo(x - 18, y - 40, x - 26, y - 120, x - 16, y - 170); ctx.lineTo(x + 18, y - 170);
        ctx.bezierCurveTo(x + 26, y - 120, x + 18, y - 40, x + 36, y); ctx.closePath();
        ctx.fillStyle = bark; ctx.fill();
        this.el(x - 2, y - 120, 9, 12, '#2E2238');
        ctx.strokeStyle = bark; ctx.lineWidth = 7;
        for (const [dx, dy] of [[-90, -230], [85, -240], [-40, -270], [45, -280], [-120, -180], [120, -190]]) {
          ctx.beginPath(); ctx.moveTo(x, y - 160); ctx.quadraticCurveTo(x + dx * 0.4, y - 170, x + dx, y + dy); ctx.stroke();
        }
        if (alive) {
          const sw = still ? 0 : S(t * 0.5) * 2;
          const canopy = dark ? mix(color, '#1E2A3A', 0.22) : color, light = mix(color, '#FFFFFF', 0.18);
          for (const [dx, dy, r] of [[-100, -200, 62], [100, -205, 62], [0, -260, 80], [-55, -275, 58], [60, -280, 56], [0, -190, 66]]) this.el(x + dx + sw, y + dy, r, r * 0.85, canopy);
          ctx.globalAlpha = 0.7;
          for (const [dx, dy, r] of [[-70, -250, 26], [40, -300, 22], [95, -225, 20]]) this.el(x + dx + sw, y + dy, r, r * 0.8, light);
          ctx.globalAlpha = 1;
        } else {
          for (const [dx, dy] of [[-90, -232], [85, -242], [-40, -272], [45, -282]]) this.el(x + dx, y + dy, 12, 4, 'rgba(244,246,255,0.85)');
        }
        break;
      }
      case 'treehouse': {
        ctx.fillStyle = '#6E4422'; ctx.fillRect(x - 40, y + 2, 80, 6);
        ctx.fillStyle = alive ? '#E8C99A' : dead; ctx.beginPath(); ctx.roundRect(x - 30, y - 40, 60, 42, 4); ctx.fill();
        ctx.beginPath(); ctx.moveTo(x - 38, y - 38); ctx.lineTo(x, y - 68); ctx.lineTo(x + 38, y - 38); ctx.closePath();
        ctx.fillStyle = alive ? color : '#6E6878'; ctx.fill();
        this.el(x, y - 20, 9, 9, alive ? (dark ? '#FFD27A' : '#8DCBEA') : '#3B3446');
        if (alive && dark) this.glow(x, y - 20, 40, '#FFD27A', 0.4);
        ctx.strokeStyle = '#6E4422'; ctx.lineWidth = 2; ctx.beginPath();
        for (const sd of [-1, 1]) { ctx.moveTo(x + 22 + sd * 5, y + 8); ctx.lineTo(x + 22 + sd * 5, y + 120); }
        for (let k = 0; k < 7; k++) { ctx.moveTo(x + 17, y + 20 + k * 15); ctx.lineTo(x + 27, y + 20 + k * 15); }
        ctx.stroke();
        break;
      }
      case 'fireflyHollow':
        ctx.fillStyle = dark ? '#5A3B2A' : '#8B5A33'; ctx.beginPath(); ctx.roundRect(x - 46, y - 26, 92, 30, 15); ctx.fill();
        this.el(x - 42, y - 11, 8, 14, '#3A2318');
        this.el(x - 42, y - 11, 5, 10, alive ? hexA(color, 0.8) : '#1E1416');
        this.el(x + 10, y - 27, 22, 5, 'rgba(125,179,86,0.7)');
        if (alive) {
          for (let i = 0; i < 14; i++) {
            const a = (still ? 0 : t * 0.5) + i * 0.9, r = 20 + i * 4;
            const fx = x - 30 + C(a) * r * 0.9, fy = y - 40 - i * 4 + S(a * 1.3) * 10;
            this.glow(fx, fy, 9, color, 0.8); this.el(fx, fy, 1.8, 1.8, '#FFFFFF');
          }
        }
        break;
      case 'standingStones':
        for (const [dx, h, tilt] of [[-38, 58, -0.06], [0, 74, 0], [38, 52, 0.07]]) {
          ctx.save(); ctx.translate(x + dx, y); ctx.rotate(tilt);
          ctx.fillStyle = dark ? '#6D6880' : '#A39FB2'; ctx.beginPath(); ctx.roundRect(-13, -h, 26, h, 10); ctx.fill();
          ctx.restore();
          if (alive) {
            const pulse = still ? 0.8 : 0.6 + 0.4 * S(t * 1.5 + dx);
            ctx.beginPath();
            ctx.moveTo(x + dx - 5, y - h * 0.7); ctx.lineTo(x + dx + 4, y - h * 0.55); ctx.lineTo(x + dx - 3, y - h * 0.4);
            ctx.moveTo(x + dx, y - h * 0.3); ctx.lineTo(x + dx, y - h * 0.15);
            ctx.strokeStyle = hexA(color, pulse); ctx.lineWidth = 2.5; ctx.stroke();
            this.glow(x + dx, y - h * 0.45, 30, color, 0.35 * pulse);
          }
        }
        break;
      case 'moonflowers': {
        const rnd = seeded(42);
        for (let i = 0; i < 12; i++) {
          const fx = x - 60 + rnd() * 120, fy = y - 6 + rnd() * 32, h = 14 + rnd() * 12;
          ctx.beginPath(); ctx.moveTo(fx, fy); ctx.lineTo(fx, fy - h); ctx.strokeStyle = '#4E7A5A'; ctx.lineWidth = 1.5; ctx.stroke();
          if (alive) { if (dark) this.glow(fx, fy - h, 14, color, 0.5); flower(ctx, fx, fy - h, 5, color, '#FFF4D6'); }
          else this.el(fx, fy - h, 3, 5, '#8C9A8A');
        }
        break;
      }
      case 'starShrine':
        ctx.beginPath(); ctx.moveTo(x - 30, y); ctx.lineTo(x - 30, y - 50);
        ctx.quadraticCurveTo(x, y - 90, x + 30, y - 50); ctx.lineTo(x + 30, y);
        ctx.strokeStyle = dark ? '#8A85A0' : '#B8B3C6'; ctx.lineWidth = 10; ctx.stroke();
        if (alive) {
          const bob = still ? 0 : S(t * 1.2) * 4;
          this.glow(x, y - 42 + bob, 70, color, 0.6);
          star(ctx, x, y - 42 + bob, 14, 6, color); star(ctx, x, y - 42 + bob, 7, 3, '#FFFFFF');
        }
        break;
    }
  }

  decoration(id) {
    const { ctx, t, still, dark } = this;
    switch (id) {
      case 'steppingStones':
        [300, 334, 368, 402, 436, 470].forEach((sx, i) => this.el(sx, 492 + (i % 2 ? 6 : 0), 12, 5, dark ? '#7A7285' : '#C9C3CF'));
        break;
      case 'toadstoolStools':
        for (const [sx, sy] of [[218, 482], [308, 486]]) {
          ctx.fillStyle = '#FFF1DC'; ctx.beginPath(); ctx.roundRect(sx - 5, sy - 12, 10, 12, 3); ctx.fill();
          this.el(sx, sy - 13, 13, 6, '#D9534F'); this.el(sx - 4, sy - 15, 2, 1.4, '#FFF4E0');
        }
        break;
      case 'windChimes':
        ctx.fillStyle = '#7A5236'; ctx.fillRect(468, 395, 4, 55); ctx.fillRect(452, 395, 36, 3);
        for (let k = 0; k < 4; k++) {
          const cx = 456 + k * 9, sw = still ? 0 : S(t * 2 + k) * 2;
          ctx.beginPath(); ctx.moveTo(cx, 398); ctx.lineTo(cx + sw, 408); ctx.strokeStyle = '#B8A88A'; ctx.lineWidth = 0.8; ctx.stroke();
          ctx.fillStyle = '#C9B27C'; ctx.beginPath(); ctx.roundRect(cx + sw - 1.5, 408, 3, 12 + (k % 2) * 4, 1.5); ctx.fill();
        }
        break;
      case 'birdhouse':
        ctx.fillStyle = '#7A5236'; ctx.fillRect(178, 410, 4, 40);
        ctx.fillStyle = '#E3A962'; ctx.beginPath(); ctx.roundRect(168, 392, 24, 20, 2); ctx.fill();
        ctx.beginPath(); ctx.moveTo(164, 394); ctx.lineTo(180, 380); ctx.lineTo(196, 394); ctx.closePath(); ctx.fillStyle = '#C94A47'; ctx.fill();
        this.el(180, 401, 3.5, 3.5, '#2E2238');
        break;
      case 'paperLanterns': {
        ctx.beginPath(); ctx.moveTo(70, 330); ctx.quadraticCurveTo(270, 380, 470, 336);
        ctx.strokeStyle = '#5A4A52'; ctx.lineWidth = 1; ctx.stroke();
        const cols = ['#FFB347', '#E8674A', '#FFD27A', '#B79CFF', '#FFB347', '#E8674A', '#FFD27A'];
        cols.forEach((col, k) => {
          const f = (k + 0.5) / cols.length, lx = 70 + f * 400;
          const ly = (1 - f) ** 2 * 330 + 2 * (1 - f) * f * 380 + f * f * 336, sw = still ? 0 : S(t * 1.4 + k) * 1.5;
          if (dark) this.glow(lx + sw, ly + 10, 22, col, 0.45);
          ctx.fillStyle = col; ctx.beginPath(); ctx.roundRect(lx - 6 + sw, ly + 2, 12, 15, 5); ctx.fill();
        });
        break;
      }
      case 'fairyLights':
        for (let k = 0, fx = 60; fx <= 500; fx += 55, k++) {
          const fy = 532 + (k % 2 ? 10 : 0), pulse = still ? 0.8 : 0.6 + 0.4 * S(t * 2 + k);
          this.glow(fx, fy - 8, 18, '#FFE07A', 0.5 * pulse);
          ctx.fillStyle = 'rgba(220,239,245,0.8)'; ctx.beginPath(); ctx.roundRect(fx - 5, fy - 14, 10, 13, 3); ctx.fill();
          this.el(fx, fy - 8, 2, 2, '#FFF4C0');
        }
        break;
    }
  }

  companion(id) { drawCompanion(this.ctx, id, this.t, this.still, this.dark); }

  fireflies() {
    const count = 3 + Object.keys(this.snap.restored).length * 3, strength = this.phase === 'day' ? 0.35 : 0.9;
    for (let i = 0; i < count; i++) {
      const sx = (i * 7919) % 1600;
      if (!this.snap.unlockedAreas.includes(this.areaOf(sx)) || sx < this.vp[0] - 30 || sx > this.vp[1] + 30) continue;
      const a = this.still ? i : this.t * (0.2 + (i % 5) * 0.05) + i;
      const x = sx + S(a) * 30, y = 360 + ((i * 137) % 140) + C(a * 1.3) * 18;
      const p = this.still ? 0.8 : 0.5 + 0.5 * S(this.t * 2.5 + i * 1.7);
      this.glow(x, y, 10, '#FFE07A', strength * p * 0.7);
      this.el(x, y, 1.4, 1.4, `rgba(255,248,214,${strength * p})`);
    }
  }

  frost() {
    if (this.still) return;
    for (let i = 0; i < 26; i++) {
      const x0 = (i * 263) % 1600;
      if (x0 < this.vp[0] - 20 || x0 > this.vp[1] + 20) continue;
      const fall = (this.t * (0.03 + (i % 4) * 0.01) + i * 0.13) % 1;
      this.el(x0 + S(this.t * 0.5 + i) * 14, fall * 560, 1.8, 1.8, `rgba(255,255,255,${0.6 * (1 - this.vitality * 2.5)})`);
    }
  }

  fog() {
    const { ctx } = this;
    for (const a of AREAS) {
      if (this.snap.unlockedAreas.includes(a.id)) continue;
      const x0 = a.xStart - 50, x1 = a.xEnd + 10;
      if (x1 < this.vp[0] || x0 > this.vp[1]) continue;
      const fc = this.dark ? '#2A2245' : '#EDE7F5';
      const g = ctx.createLinearGradient(x0, 0, x1, 0);
      g.addColorStop(0, hexA(fc, 0)); g.addColorStop(0.12, hexA(fc, 0.94)); g.addColorStop(1, hexA(fc, 0.97));
      ctx.fillStyle = g; ctx.fillRect(x0, 0, x1 - x0, 600);
      for (let k = 0; k < 5; k++) {
        const d = this.still ? 0 : S(this.t * 0.15 + k) * 20;
        this.el(x0 + 60 + (k * (x1 - x0 - 60)) / 5 + d, 380 + (k % 2) * 60, 90, 40, this.dark ? 'rgba(58,48,96,0.5)' : 'rgba(255,255,255,0.5)');
      }
    }
  }
}

const decorDepth = { steppingStones: 480, paperLanterns: 300, fairyLights: 530, toadstoolStools: 482 };
const companionDepth = { tansy: 476, mosslings: 470, pebble: 471, wren: 426, hoot: 441, glimmer: 461, nox: 440 };

export const COMPANION_FRAMES = {
  tansy: [192, 458, 72], mosslings: [124, 464, 110], pebble: [612, 460, 40], wren: [853, 346, 36],
  hoot: [1058, 316, 42], glimmer: [1230, 428, 40], nox: [1383, 422, 60],
};

export function drawCompanion(ctx, id, t = 2, still = true, dark = false) {
  const el = (x, y, rx, ry, c) => ellipse(ctx, x, y, rx, ry, c);
  const bob = still ? 0 : S(t * 1.8 + id.length) * 1.5;
  switch (id) {
    case 'tansy': {
      const x = 200, y = 476, wag = still ? 0 : S(t * 2.4) * 0.25;
      ctx.save(); ctx.translate(x - 18, y - 10); ctx.rotate(-0.6 + wag); el(0, 0, 20, 9, '#E98A3C'); ctx.restore();
      el(x - 33 + wag * 10, y - 21, 6, 5, '#FFF4E0');
      el(x, y - 12 + bob * 0.3, 15, 13, '#F09A4A'); el(x + 2, y - 8 + bob * 0.3, 8, 8, '#FFF4E0');
      const hy = y - 30 + bob;
      el(x + 4, hy, 12, 10, '#F09A4A');
      for (const sd of [-1, 1]) {
        ctx.beginPath(); ctx.moveTo(x + 4 + sd * 9, hy - 4); ctx.lineTo(x + 4 + sd * 9, hy - 18); ctx.lineTo(x + 4 + sd * 2, hy - 8); ctx.closePath();
        ctx.fillStyle = '#D9782E'; ctx.fill();
      }
      el(x + 13, hy + 3, 5, 3.5, '#FFF4E0'); el(x + 17, hy + 2, 1.6, 1.4, '#2E2238');
      el(x + 3, hy - 1, 1.6, dark ? 0.6 : 1.8, '#2E2238'); el(x + 10, hy - 1, 1.6, dark ? 0.6 : 1.8, '#2E2238');
      break;
    }
    case 'mosslings':
      [[80, 470], [150, 474], [168, 466]].forEach(([sx, sy], k) => {
        const cr = still ? 0 : S(t * 0.3 + k) * 4;
        el(sx + cr + 5, sy, 9, 3.5, '#B9C79A'); el(sx + cr, sy - 6, 7, 7, '#8DBF5A');
        ctx.beginPath(); ctx.arc(sx + cr, sy - 6, 3.5, 0, PI * 2); ctx.strokeStyle = '#5E8F3E'; ctx.lineWidth = 1.2; ctx.stroke();
        el(sx + cr + 12, sy - 6, 1.2, 1.2, '#2E2238');
      });
      break;
    case 'pebble': {
      const x = 612, y = 466 + bob * 0.5;
      el(x, y, 12, 8, '#6DB359'); el(x, y + 2, 8, 4, '#C6E58E');
      for (const sd of [-1, 1]) { el(x + sd * 6, y - 8, 4.5, 4.5, '#6DB359'); el(x + sd * 6, y - 8, 2, 2.2, '#2E2238'); }
      break;
    }
    case 'wren': {
      const x = 857, y = 351 + bob;
      el(x, y, 8, 6, '#9A6A44'); el(x + 6, y - 5, 4.5, 4.5, '#9A6A44');
      ctx.beginPath(); ctx.moveTo(x - 6, y - 1); ctx.lineTo(x - 13, y - 11); ctx.lineTo(x - 9, y - 12); ctx.closePath(); ctx.fillStyle = '#7A5236'; ctx.fill();
      ctx.beginPath(); ctx.moveTo(x + 10, y - 6); ctx.lineTo(x + 14, y - 5); ctx.lineTo(x + 10, y - 4); ctx.fillStyle = '#F2C14E'; ctx.fill();
      el(x + 7, y - 6, 1, 1, '#2E2238');
      break;
    }
    case 'hoot': {
      const x = 1058, y = 322 + bob * 0.4, blink = !still && t % 5 < 0.2;
      el(x, y, 11, 13, '#8B6A4E'); el(x, y + 4, 7, 7, '#D9C3A0');
      for (const sd of [-1, 1]) {
        el(x + sd * 5, y - 5, 5, 5, '#FFF4E0'); el(x + sd * 5, y - 5, 2.4, blink ? 0.4 : 2.4, '#2E2238');
        ctx.beginPath(); ctx.moveTo(x + sd * 4, y - 11); ctx.lineTo(x + sd * 11, y - 18); ctx.lineTo(x + sd * 10, y - 9); ctx.fillStyle = '#8B6A4E'; ctx.fill();
      }
      break;
    }
    case 'glimmer': {
      const a = still ? 0 : t * 0.8, x = 1200 + C(a) * 30, y = 430 + S(a * 1.6) * 12;
      radialGlow(ctx, x, y, 26, '#FFE07A', 0.9); el(x, y, 3, 3, '#FFFFFF'); star(ctx, x, y - 7, 3.5, 1.5, '#F2C14E');
      break;
    }
    case 'nox': {
      const x = 1385, y = 440, hop = still ? 0 : Math.max(0, S(t * 1.4)) * 6;
      el(x, y - 10 - hop, 14, 11, '#D9DCEB'); el(x + 10, y - 20 - hop, 8, 7, '#D9DCEB');
      for (const [dx, ang] of [[8, -0.2], [13, 0.15]]) {
        ctx.save(); ctx.translate(x + dx, y - 25 - hop); ctx.rotate(ang); el(0, -11, 3.2, 11, '#C9CDE0'); ctx.restore();
      }
      el(x + 13, y - 21 - hop, 1.4, 1.6, '#2E2238'); el(x - 13, y - 12 - hop, 4, 4, '#FFFFFF');
      sparkle(ctx, x - 4, y - 34 - hop, 4 * (still ? 1 : 0.6 + 0.4 * S(t * 3)), '#BFE2FF');
      break;
    }
  }
}

/** Shop illustration of a decoration, drawn in a 100×100 box. */
export function drawDecorThumb(ctx, id, t = 2, still = true) {
  const el = (x, y, rx, ry, c) => ellipse(ctx, x, y, rx, ry, c);
  const rect = (x, y, w, h, r, c) => { ctx.fillStyle = c; ctx.beginPath(); ctx.roundRect(x, y, w, h, r); ctx.fill(); };
  const sway = (k, amt) => (still ? 0 : S(t * 1.6 + k) * amt);
  el(50, 86, 46, 11, '#86B56A'); el(50, 84, 42, 8, '#A8D07F');
  for (const [gx, gy] of [[14, 84], [86, 85], [30, 90], [72, 90]]) {
    ctx.beginPath(); ctx.moveTo(gx - 2, gy); ctx.lineTo(gx, gy - 5); ctx.lineTo(gx + 2, gy); ctx.fillStyle = '#6E9E52'; ctx.fill();
  }
  switch (id) {
    case 'steppingStones':
      [[22, 88, 10], [40, 80, 9], [58, 86, 10], [75, 78, 8]].forEach(([x, y, r]) => {
        el(x, y + 1.6, r, r * 0.46, '#8F8899'); el(x, y, r, r * 0.46, '#D6D0DC'); el(x - r * 0.3, y - 1, r * 0.35, r * 0.14, '#F1EDF4');
      });
      break;
    case 'toadstoolStools':
      for (const [x, s] of [[34, 1], [68, 0.78]]) {
        const top = 85 - 24 * s;
        rect(x - 7 * s, top, 14 * s, 24 * s, 5 * s, '#FFF1DC'); rect(x - 7 * s, top + 16 * s, 14 * s, 8 * s, 5 * s, '#EADBC4');
        el(x, top + 2, 19 * s, 8 * s, '#B8403C'); el(x, top, 19 * s, 8 * s, '#D9534F');
        for (const [dx, dy, r] of [[-9, -1, 2.6], [3, -3, 2.2], [11, 1, 1.8], [-2, 3, 1.6]]) el(x + dx * s, top + dy * s, r * s, r * 0.7 * s, '#FFF4E0');
      }
      break;
    case 'windChimes': {
      ctx.strokeStyle = '#7A5236'; ctx.lineWidth = 3.5; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(8, 14); ctx.quadraticCurveTo(50, 6, 94, 16); ctx.stroke();
      ellipse(ctx, 80, 12, 6, 3, '#8DBF5A'); ellipse(ctx, 22, 11, 5, 2.5, '#8DBF5A');
      ctx.lineWidth = 1; ctx.strokeStyle = '#B8A88A';
      ctx.beginPath(); ctx.moveTo(50, 10); ctx.lineTo(50, 22); ctx.stroke();
      el(50, 24, 16, 3, '#9A6A44');
      for (let k = 0; k < 5; k++) {
        const cx = 38 + k * 6, sw = sway(k, 2), len = 22 + [0, 8, 14, 8, 0][k];
        ctx.beginPath(); ctx.moveTo(cx, 25); ctx.lineTo(cx + sw, 30); ctx.stroke();
        rect(cx + sw - 2, 30, 4, len, 2, '#D8C188'); rect(cx + sw - 2, 30, 1.4, len, 1, '#F4E4B4');
      }
      ctx.beginPath(); ctx.moveTo(50, 25); ctx.lineTo(50 + sway(9, 3), 62); ctx.stroke();
      el(50 + sway(9, 3), 66, 3.5, 4.5, '#E8674A');
      break;
    }
    case 'birdhouse': {
      rect(47, 46, 6, 40, 1, '#7A5236');
      rect(32, 30, 36, 28, 3, '#E3A962'); rect(32, 52, 36, 6, 2, '#C98D4A');
      ctx.beginPath(); ctx.moveTo(26, 33); ctx.lineTo(50, 12); ctx.lineTo(74, 33); ctx.closePath(); ctx.fillStyle = '#C94A47'; ctx.fill();
      ctx.beginPath(); ctx.moveTo(26, 33); ctx.lineTo(50, 12); ctx.lineTo(50, 17); ctx.lineTo(31, 34); ctx.closePath(); ctx.fillStyle = '#E06560'; ctx.fill();
      el(50, 40, 6, 6, '#3A2A3E'); rect(48, 49, 4, 7, 1, '#7A5236');
      const hop = still ? 0 : Math.max(0, S(t * 2)) * 2;
      el(66, 26 - hop, 6, 4.5, '#9A6A44'); el(70, 22 - hop, 3.6, 3.6, '#9A6A44'); el(71, 21.5 - hop, 0.9, 0.9, '#2E2238');
      ctx.beginPath(); ctx.moveTo(73, 22 - hop); ctx.lineTo(76.5, 22.6 - hop); ctx.lineTo(73, 23.6 - hop); ctx.fillStyle = '#F2C14E'; ctx.fill();
      break;
    }
    case 'paperLanterns': {
      ctx.beginPath(); ctx.moveTo(4, 18); ctx.quadraticCurveTo(50, 44, 96, 18); ctx.strokeStyle = '#5A4A52'; ctx.lineWidth = 1.2; ctx.stroke();
      [['#FFB347', 0.2], ['#E8674A', 0.5], ['#B79CFF', 0.8]].forEach(([col, f], k) => {
        const x = 4 + f * 92, y = (1 - f) ** 2 * 18 + 2 * (1 - f) * f * 44 + f * f * 18, sw = sway(k, 1.5);
        radialGlow(ctx, x + sw, y + 18, 26, col, 0.35);
        rect(x - 5 + sw, y, 10, 3, 1, '#5A4A52');
        rect(x - 10 + sw, y + 3, 20, 26, 9, col);
        ctx.strokeStyle = 'rgba(90,58,40,0.25)'; ctx.lineWidth = 0.8;
        for (const dx of [-4, 0, 4]) { ctx.beginPath(); ctx.moveTo(x + sw + dx, y + 4); ctx.lineTo(x + sw + dx, y + 28); ctx.stroke(); }
        el(x - 4 + sw, y + 11, 2.5, 5, 'rgba(255,255,255,0.35)');
        rect(x - 4 + sw, y + 29, 8, 3, 1, '#5A4A52');
      });
      break;
    }
    case 'fairyLights':
      [[28, 78, 1], [54, 82, 1.15], [77, 76, 0.9]].forEach(([x, y, s], k) => {
        const pulse = still ? 0.8 : 0.6 + 0.4 * S(t * 2 + k * 1.3);
        radialGlow(ctx, x, y - 12 * s, 24 * s, '#FFE07A', 0.55 * pulse);
        rect(x - 9 * s, y - 24 * s, 18 * s, 24 * s, 5 * s, 'rgba(220,239,245,0.75)');
        rect(x - 7 * s, y - 28 * s, 14 * s, 5 * s, 1.5 * s, '#9A6A44');
        el(x, y - 11 * s, 3 * s, 3 * s, '#FFF4C0'); el(x - 4 * s, y - 16 * s, 1.6 * s, 1.6 * s, '#FFF4C0');
        el(x - 5 * s, y - 18 * s, 1.5 * s, 4 * s, 'rgba(255,255,255,0.5)');
      });
      for (let k = 0; k < 4; k++) {
        const a = still ? k : t * 0.7 + k * 1.6;
        sparkle(ctx, 50 + S(a) * 34, 34 + C(a * 1.3) * 14, 2.2, '#FFE07A');
      }
      break;
  }
}
