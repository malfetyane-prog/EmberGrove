// All sound is synthesized in the browser. Effects play live through Web Audio. Ambience is rendered
// offline into a seamless loop and played through an <audio> element, because iPhone keeps media
// playing when the screen locks but suspends Web Audio.
import { AMBIENCE } from './content.js';

let ctx = null, master = null;
let ac = null, out = null, events = null; // the offline context, its output and pending notes while a bed is being rendered
let player = null, blessed = false, job = 0, bed = null, track = null;

const RATE = 32000, FADE = 1.5;

function ensure() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain(); master.gain.value = 0.9; master.connect(ctx.destination);
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

function element() {
  if (!player) {
    player = new Audio(); player.loop = true; player.preload = 'auto';
    player.setAttribute('playsinline', '');
    if ('mediaSession' in navigator) {
      navigator.mediaSession.setActionHandler('play', () => player.play().catch(() => {}));
      navigator.mediaSession.setActionHandler('pause', () => player.pause());
    }
  }
  return player;
}

/** Must be called from a tap so iOS lets audio start later, including the ambience player. */
export function unlock() {
  ensure();
  const p = element();
  if (blessed) return;
  blessed = true;
  const silence = URL.createObjectURL(wav([new Float32Array(RATE / 10)], 1));
  p.src = silence;
  p.play().then(() => { if (p.src === silence) p.pause(); }).catch(() => { blessed = false; });
}

// ---------------------------------------------------------------- Building blocks (render into `ac`)
function noiseBuffer(kind, seconds = 4) {
  const len = ac.sampleRate * seconds, buf = ac.createBuffer(1, len, ac.sampleRate), d = buf.getChannelData(0);
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0, brown = 0;
  for (let i = 0; i < len; i++) {
    const w = Math.random() * 2 - 1;
    if (kind === 'brown') { brown = (brown + 0.02 * w) / 1.02; d[i] = brown * 3.2; }
    else if (kind === 'pink') {
      b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759; b2 = 0.969 * b2 + w * 0.153852;
      b3 = 0.8665 * b3 + w * 0.3104856; b4 = 0.55 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.016898;
      d[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11; b6 = w * 0.115926;
    } else d[i] = w;
  }
  return buf;
}

function loop(kind, gain, filter) {
  const src = ac.createBufferSource(); src.buffer = noiseBuffer(kind); src.loop = true;
  const g = ac.createGain(); g.gain.value = gain;
  let node = src, f = null;
  if (filter) { f = ac.createBiquadFilter(); f.type = filter.type; f.frequency.value = filter.freq; f.Q.value = filter.q || 0.7; src.connect(f); node = f; }
  node.connect(g); g.connect(out); src.start(0);
  return { src, g, f };
}

/** Calls fn(time) at random intervals across the whole render. */
function every(minMs, maxMs, len, fn) {
  for (let t = minMs / 1000; t < len; t += (minMs + Math.random() * (maxMs - minMs)) / 1000) events.push([t, () => fn(t)]);
}

/** Calls fn(step, time) on a fixed grid across the whole render. */
function sequence(stepSeconds, len, fn) {
  for (let step = 0, t = 0; t < len; t = ++step * stepSeconds) { const i = step, at = t; events.push([at, () => fn(i, at)]); }
}

let burst = null;
function noiseBurst() { if (!burst || burst.sampleRate !== ac.sampleRate) burst = noiseBuffer('white', 1); return burst; }

function hit(dest, t, { type, freq, q = 0.8, gain, len }) {
  const src = ac.createBufferSource(), f = ac.createBiquadFilter(), g = ac.createGain();
  src.buffer = noiseBurst(); f.type = type; f.frequency.value = freq; f.Q.value = q;
  g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(0.001, t + len);
  src.connect(f); f.connect(g); g.connect(dest); src.start(t, Math.random() * 0.8); src.stop(t + len + 0.02);
}

function drop(t) {
  const o = ac.createOscillator(), g = ac.createGain();
  o.frequency.setValueAtTime(1400 + Math.random() * 1800, t); o.frequency.exponentialRampToValueAtTime(900, t + 0.12);
  g.gain.setValueAtTime(0.04, t); g.gain.exponentialRampToValueAtTime(0.0005, t + 0.15);
  o.connect(g); g.connect(out); o.start(t); o.stop(t + 0.16);
}

function birdSong(t0) {
  const n = 2 + Math.floor(Math.random() * 3), base = 2600 + Math.random() * 1200, len = 0.05 + Math.random() * 0.04;
  for (let i = 0; i < n; i++) {
    const t = t0 + i * (len + 0.07), o = ac.createOscillator(), g = ac.createGain();
    o.frequency.setValueAtTime(base, t); o.frequency.linearRampToValueAtTime(base + 1500, t + len);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.035, t + len / 2); g.gain.linearRampToValueAtTime(0, t + len);
    o.connect(g); g.connect(out); o.start(t); o.stop(t + len + 0.01);
  }
}

const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);

function epiano(dest, wobble, note, t, len, vel) {
  for (const [mult, amp, type] of [[1, 1, 'sine'], [2, 0.18, 'triangle'], [4.01, 0.04, 'sine']]) {
    const o = ac.createOscillator(), g = ac.createGain();
    o.type = type; o.frequency.value = midi(note) * mult; wobble.connect(o.detune);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(vel * amp, t + 0.015);
    g.gain.setTargetAtTime(vel * amp * 0.5, t + 0.015, 0.4); g.gain.setTargetAtTime(0, t + len, 0.25);
    o.connect(g); g.connect(dest); o.start(t); o.stop(t + len + 1.5);
  }
}

function kick(dest, t) {
  const o = ac.createOscillator(), g = ac.createGain();
  o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.14);
  g.gain.setValueAtTime(0.75, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
  o.connect(g); g.connect(dest); o.start(t); o.stop(t + 0.42);
}

function bassNote(dest, note, t, len) {
  const o = ac.createOscillator(), g = ac.createGain();
  o.frequency.value = midi(note);
  g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.32, t + 0.03); g.gain.setTargetAtTime(0, t + len, 0.12);
  o.connect(g); g.connect(dest); o.start(t); o.stop(t + len + 0.8);
}

// ---------------------------------------------------------------- Sound beds
const LOFI_TEMPO = 74, LOFI_BARS = 16;
const LOFI_CHORDS = [[50, [53, 57, 60, 64]], [43, [53, 57, 59, 64]], [48, [52, 55, 59, 62]], [45, [52, 55, 60, 64]]]; // Dm9 · G13 · Cmaj9 · Am9

const BEDS = {
  campfire: { seconds: 60, build(len) {
    loop('brown', 0.55, { type: 'lowpass', freq: 600 });
    loop('white', 0.02, { type: 'bandpass', freq: 3000, q: 0.5 });
    every(60, 260, len, (t) => hit(out, t, { type: 'highpass', freq: 1500 + Math.random() * 2500, gain: 0.15 + Math.random() * 0.35, len: 0.02 + Math.random() * 0.05 }));
  } },
  rain: { seconds: 60, build(len) {
    loop('pink', 0.5, { type: 'lowpass', freq: 5000 });
    every(80, 500, len, drop);
  } },
  breeze: { seconds: 60, build(len) {
    const { f } = loop('white', 0.25, { type: 'lowpass', freq: 500 });
    const lfo = ac.createOscillator(), depth = ac.createGain();
    lfo.frequency.value = 1 / 15; depth.gain.value = 350; lfo.connect(depth); depth.connect(f.frequency); lfo.start(0);
    every(5000, 14000, len, birdSong);
  } },
  // Lo-fi: a slow, swung hip-hop loop with soft keys, a warm bass, dusty drums and vinyl hiss.
  lofi: { seconds: LOFI_BARS * 4 * 60 / LOFI_TEMPO, build(len) {
    const f = ac.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 3200; f.connect(out);
    const wobble = ac.createGain(), lfo = ac.createOscillator();
    lfo.frequency.value = 0.5; wobble.gain.value = 7; lfo.connect(wobble); lfo.start(0); // tape wow
    loop('pink', 0.035, { type: 'bandpass', freq: 2500, q: 0.4 }); // vinyl hiss
    every(120, 900, len, (t) => hit(f, t, { type: 'highpass', freq: 2500, gain: 0.05 + Math.random() * 0.08, len: 0.015 }));
    const sixteenth = 60 / LOFI_TEMPO / 4, swing = sixteenth * 0.28;
    sequence(sixteenth, len, (step, t) => {
      const s = step % 16, [root, chord] = LOFI_CHORDS[Math.floor(step / 16) % LOFI_CHORDS.length], bar = 16 * sixteenth;
      const tt = s % 2 ? t + swing : t;
      if (s === 0) chord.forEach((n, i) => epiano(f, wobble, n, t + i * 0.012, bar * 0.9, 0.085));
      if (s === 10 && Math.random() < 0.6) epiano(f, wobble, chord[2 + Math.floor(Math.random() * 2)] + 12, tt, sixteenth * 3, 0.05);
      if (s === 0 || s === 7) bassNote(f, root - 12 * (root > 47 ? 1 : 0), tt, s === 0 ? sixteenth * 6 : sixteenth * 5);
      if (s === 0 || s === 7 || (s === 10 && step % 32 > 15)) kick(f, tt);
      if (s === 4 || s === 12) hit(f, tt, { type: 'bandpass', freq: 1800, q: 0.7, gain: 0.32, len: 0.2 });
      if (s % 2 === 0 || Math.random() < 0.15) hit(f, tt, { type: 'highpass', freq: 7000, gain: s % 4 === 0 ? 0.09 : 0.05, len: 0.04 });
    });
  } },
  // Binaural focus waves: two close tones, one per ear, that the brain hears as a slow 14 Hz (beta) pulse. Needs headphones.
  binaural: { seconds: 60, stereo: true, build() {
    const merger = ac.createChannelMerger(2), carrier = 200, beat = 14;
    merger.connect(out);
    [carrier, carrier + beat].forEach((freq, ear) => {
      const o = ac.createOscillator(), g = ac.createGain();
      o.frequency.value = freq; g.gain.value = 0.22;
      o.connect(g); g.connect(merger, 0, ear); o.start(0);
    });
    // A soft drone and low rumble underneath so it feels like a place, not a test tone.
    [[100, 0.05], [150, 0.025]].forEach(([freq, gain]) => {
      const o = ac.createOscillator(), g = ac.createGain(); o.frequency.value = freq; g.gain.value = gain;
      o.connect(g); g.connect(out); o.start(0);
    });
    loop('brown', 0.25, { type: 'lowpass', freq: 400 });
  } },
};

/** Renders a bed a little past its loop length, then crossfades that tail into the start so it loops seamlessly. */
async function renderBed(kind) {
  const def = BEDS[kind], channels = def.stereo ? 2 : 1;
  const n = Math.round(def.seconds * RATE), fade = Math.round(FADE * RATE), len = (n + fade) / RATE;
  const OAC = window.OfflineAudioContext || window.webkitOfflineAudioContext;
  ac = new OAC(channels, n + fade, RATE);
  out = ac.createGain(); out.connect(ac.destination);
  events = [];
  def.build(len);
  // Notes are created a second at a time while rendering: a node that exists keeps processing even before it plays.
  const rendering = ac, ctxOut = out, pending = events.sort((a, b) => a[0] - b[0]), WINDOW = 1, LEAD = 0.25;
  let next = 0;
  const createUntil = (t) => {
    [ac, out] = [rendering, ctxOut];
    while (next < pending.length && pending[next][0] < t) pending[next++][1]();
    ac = out = null;
  };
  if (rendering.suspend) {
    createUntil(WINDOW + LEAD);
    for (let w = WINDOW; w < len; w += WINDOW) {
      rendering.suspend(w).then(() => { createUntil(w + WINDOW + LEAD); rendering.resume(); });
    }
  } else createUntil(Infinity);
  events = null;
  const buf = await new Promise((resolve, reject) => {
    rendering.oncomplete = (e) => resolve(e.renderedBuffer);
    const p = rendering.startRendering();
    if (p && p.then) p.then(resolve, reject);
  });
  return Array.from({ length: channels }, (_, c) => {
    const d = buf.getChannelData(c), o = d.slice(0, n);
    for (let i = 0; i < fade; i++) { const k = i / fade; o[i] = d[i] * k + d[n + i] * (1 - k); }
    return o;
  });
}

/** 16-bit PCM WAV with the volume baked in (iPhone ignores volume on audio elements). */
function wav(channels, gain) {
  const ch = channels.length, frames = channels[0].length, bytes = frames * ch * 2;
  const v = new DataView(new ArrayBuffer(44 + bytes));
  const str = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
  str(0, 'RIFF'); v.setUint32(4, 36 + bytes, true); str(8, 'WAVE'); str(12, 'fmt ');
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, ch, true); v.setUint32(24, RATE, true);
  v.setUint32(28, RATE * ch * 2, true); v.setUint16(32, ch * 2, true); v.setUint16(34, 16, true);
  str(36, 'data'); v.setUint32(40, bytes, true);
  for (let i = 0, o = 44; i < frames; i++) {
    for (let c = 0; c < ch; c++, o += 2) v.setInt16(o, Math.max(-1, Math.min(1, channels[c][i] * gain)) * 32767, true);
  }
  return new Blob([v], { type: 'audio/wav' });
}

function showOnLockScreen(kind) {
  if (!('mediaSession' in navigator) || !window.MediaMetadata) return;
  navigator.mediaSession.metadata = new MediaMetadata({
    title: AMBIENCE[kind]?.title || 'Ambience', artist: 'Ember Grove',
    artwork: [{ src: new URL('icons/icon-512.png', location.href).href, sizes: '512x512', type: 'image/png' }],
  });
}

// ---------------------------------------------------------------- Ambience
export function setAmbient(kind, volume = 0.6) {
  const p = element(), id = ++job;
  if (kind === 'none' || !BEDS[kind]) { p.pause(); return; }
  if (track && track.kind === kind && track.volume === volume && p.src === track.url) { p.play().catch(() => {}); return; }
  (async () => {
    if (bed?.kind !== kind) {
      const data = await renderBed(kind);
      bed = { kind, data };
    }
    if (id !== job) return;
    const keepTime = track?.kind === kind ? p.currentTime : 0;
    if (track) URL.revokeObjectURL(track.url);
    track = { kind, volume, url: URL.createObjectURL(wav(bed.data, volume * 0.9)) };
    p.src = track.url;
    if (keepTime) p.addEventListener('loadedmetadata', () => { p.currentTime = keepTime; }, { once: true });
    showOnLockScreen(kind);
    p.play().catch(() => {});
  })();
}

export function stopAmbient() { setAmbient('none'); }

// ---------------------------------------------------------------- Effects
const EFFECTS = {
  start: [[523.25, 0, 1.2, 0.35], [783.99, 0.12, 1.4, 0.3]],
  complete: [[523.25, 0, 1.4, 0.3], [659.25, 0.14, 1.4, 0.3], [783.99, 0.28, 1.6, 0.3], [1046.5, 0.46, 2, 0.28]],
  levelUp: [[587.33, 0, 1, 0.25], [739.99, 0.09, 1, 0.25], [880, 0.18, 1, 0.25], [1174.66, 0.27, 1.8, 0.3], [1479.98, 0.36, 2, 0.2]],
  discover: [[987.77, 0, 1.4, 0.25], [1318.51, 0.18, 1.8, 0.25]],
  tap: [[880, 0, 0.35, 0.15]],
};

export function play(name, enabled = true) {
  if (!enabled || !ensure()) return;
  const now = ctx.currentTime;
  for (const [freq, start, len, gain] of EFFECTS[name] || []) {
    for (const [mult, amp, decay] of [[1, 1, 3.2], [2, 0.45, 4], [3.01, 0.25, 6]]) {
      const o = ctx.createOscillator(), g = ctx.createGain(), t = now + start;
      o.frequency.value = freq * mult;
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(gain * amp * 0.35, t + 0.006);
      g.gain.exponentialRampToValueAtTime(0.0001, t + Math.min(len, 3 / decay * 2));
      o.connect(g); g.connect(master); o.start(t); o.stop(t + len);
    }
  }
}
