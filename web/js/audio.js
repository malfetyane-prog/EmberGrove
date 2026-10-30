// All sound is synthesized in the browser: ambient beds from noise, effects from bell tones.
let ctx = null, master = null, ambientGain = null, ambientNodes = [], ambientTimers = [], current = 'none', generation = 0;

function ensure() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain(); master.gain.value = 0.9; master.connect(ctx.destination);
    ambientGain = ctx.createGain(); ambientGain.gain.value = 0; ambientGain.connect(master);
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

/** Must be called from a tap so iOS lets audio start. */
export function unlock() { ensure(); }

function noiseBuffer(kind, seconds = 4) {
  const len = ctx.sampleRate * seconds, buf = ctx.createBuffer(1, len, ctx.sampleRate), d = buf.getChannelData(0);
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
  const src = ctx.createBufferSource(); src.buffer = noiseBuffer(kind); src.loop = true;
  const g = ctx.createGain(); g.gain.value = gain;
  let node = src;
  if (filter) { const f = ctx.createBiquadFilter(); Object.assign(f, { type: filter.type }); f.frequency.value = filter.freq; f.Q.value = filter.q || 0.7; src.connect(f); node = f; ambientNodes.push(f); }
  node.connect(g); g.connect(ambientGain); src.start();
  ambientNodes.push(src, g);
  return { src, g };
}

function every(minMs, maxMs, fn) {
  let id;
  const tick = () => { fn(); id = setTimeout(tick, minMs + Math.random() * (maxMs - minMs)); ambientTimers.push(id); };
  id = setTimeout(tick, minMs); ambientTimers.push(id);
}

function crackle() {
  const t = ctx.currentTime, len = 0.02 + Math.random() * 0.05;
  const src = ctx.createBufferSource(); src.buffer = noiseBuffer('white', 0.1);
  const f = ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 1500 + Math.random() * 2500;
  const g = ctx.createGain(); g.gain.setValueAtTime(0.15 + Math.random() * 0.35, t); g.gain.exponentialRampToValueAtTime(0.001, t + len);
  src.connect(f); f.connect(g); g.connect(ambientGain); src.start(t); src.stop(t + len + 0.02);
}

function drop() {
  const t = ctx.currentTime, o = ctx.createOscillator(), g = ctx.createGain();
  o.frequency.setValueAtTime(1400 + Math.random() * 1800, t); o.frequency.exponentialRampToValueAtTime(900, t + 0.12);
  g.gain.setValueAtTime(0.04, t); g.gain.exponentialRampToValueAtTime(0.0005, t + 0.15);
  o.connect(g); g.connect(ambientGain); o.start(t); o.stop(t + 0.16);
}

function birdSong() {
  const n = 2 + Math.floor(Math.random() * 3), base = 2600 + Math.random() * 1200, len = 0.05 + Math.random() * 0.04;
  for (let i = 0; i < n; i++) {
    const t = ctx.currentTime + i * (len + 0.07), o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.setValueAtTime(base, t); o.frequency.linearRampToValueAtTime(base + 1500, t + len);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.035, t + len / 2); g.gain.linearRampToValueAtTime(0, t + len);
    o.connect(g); g.connect(ambientGain); o.start(t); o.stop(t + len + 0.01);
  }
}

function stopNodes() {
  generation++;
  ambientTimers.forEach(clearTimeout); ambientTimers = [];
  const nodes = ambientNodes; ambientNodes = [];
  setTimeout(() => nodes.forEach((n) => { try { n.stop?.(); n.disconnect(); } catch (e) { /* already stopped */ } }), 700);
}

// A sub-mix for a sound bed. Disconnecting it on stop also silences any notes already scheduled ahead.
function bus(gain = 1, lowpass = 0) {
  const g = ctx.createGain(); g.gain.value = gain;
  let input = g;
  if (lowpass) { const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = lowpass; f.connect(g); input = f; ambientNodes.push(f); }
  g.connect(ambientGain); ambientNodes.push(g);
  return input;
}

/** Calls fn(step, time) for each step, scheduled slightly ahead so timing stays tight. */
function sequence(stepSeconds, fn) {
  const gen = generation;
  let next = ctx.currentTime + 0.1, step = 0;
  const tick = () => {
    if (gen !== generation) return;
    if (next < ctx.currentTime) next = ctx.currentTime + 0.05; // resumed after a stall: don't burst-play missed notes
    while (next < ctx.currentTime + 0.4) { fn(step, next); next += stepSeconds; step++; }
    setTimeout(tick, 120);
  };
  tick();
}

const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);
let burst = null;
function noiseBurst() { if (!burst || burst.sampleRate !== ctx.sampleRate) burst = noiseBuffer('white', 1); return burst; }

function epiano(out, wobble, note, t, len, vel) {
  for (const [mult, amp, type] of [[1, 1, 'sine'], [2, 0.18, 'triangle'], [4.01, 0.04, 'sine']]) {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = type; o.frequency.value = midi(note) * mult; wobble.connect(o.detune); o.onended = () => { try { wobble.disconnect(o.detune); } catch (e) { /* bed already stopped */ } };
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(vel * amp, t + 0.015);
    g.gain.setTargetAtTime(vel * amp * 0.5, t + 0.015, 0.4); g.gain.setTargetAtTime(0, t + len, 0.25);
    o.connect(g); g.connect(out); o.start(t); o.stop(t + len + 1.5);
  }
}

function kick(out, t) {
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.14);
  g.gain.setValueAtTime(0.75, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
  o.connect(g); g.connect(out); o.start(t); o.stop(t + 0.42);
}

function hit(out, t, { type, freq, q = 0.8, gain, len }) {
  const src = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
  src.buffer = noiseBurst(); f.type = type; f.frequency.value = freq; f.Q.value = q;
  g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(0.001, t + len);
  src.connect(f); f.connect(g); g.connect(out); src.start(t, Math.random() * 0.8); src.stop(t + len + 0.02);
}

function bassNote(out, note, t, len) {
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.frequency.value = midi(note);
  g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.32, t + 0.03); g.gain.setTargetAtTime(0, t + len, 0.12);
  o.connect(g); g.connect(out); o.start(t); o.stop(t + len + 0.8);
}

// Lo-fi: a slow, swung hip-hop loop with soft keys, a warm bass, dusty drums and vinyl hiss.
const LOFI_CHORDS = [[50, [53, 57, 60, 64]], [43, [53, 57, 59, 64]], [48, [52, 55, 59, 62]], [45, [52, 55, 60, 64]]]; // Dm9 · G13 · Cmaj9 · Am9
function lofi() {
  const out = bus(1, 3200);
  const wobble = ctx.createGain(), lfo = ctx.createOscillator();
  lfo.frequency.value = 0.5; wobble.gain.value = 7; lfo.connect(wobble); lfo.start(); // tape wow
  ambientNodes.push(lfo, wobble);
  loop('pink', 0.035, { type: 'bandpass', freq: 2500, q: 0.4 }); // vinyl hiss
  every(120, 900, () => hit(out, ctx.currentTime, { type: 'highpass', freq: 2500, gain: 0.05 + Math.random() * 0.08, len: 0.015 }));
  const sixteenth = 60 / 74 / 4, swing = sixteenth * 0.28;
  sequence(sixteenth, (step, t) => {
    const s = step % 16, [root, chord] = LOFI_CHORDS[Math.floor(step / 16) % LOFI_CHORDS.length], bar = 16 * sixteenth;
    const tt = s % 2 ? t + swing : t;
    if (s === 0) chord.forEach((n, i) => epiano(out, wobble, n, t + i * 0.012, bar * 0.9, 0.085));
    if (s === 10 && Math.random() < 0.6) epiano(out, wobble, chord[2 + Math.floor(Math.random() * 2)] + 12, tt, sixteenth * 3, 0.05);
    if (s === 0 || s === 7) bassNote(out, root - 12 * (root > 47 ? 1 : 0), tt, s === 0 ? sixteenth * 6 : sixteenth * 5);
    if (s === 0 || s === 7 || (s === 10 && step % 32 > 15)) kick(out, tt);
    if (s === 4 || s === 12) hit(out, tt, { type: 'bandpass', freq: 1800, q: 0.7, gain: 0.32, len: 0.2 });
    if (s % 2 === 0 || Math.random() < 0.15) hit(out, tt, { type: 'highpass', freq: 7000, gain: s % 4 === 0 ? 0.09 : 0.05, len: 0.04 });
  });
}

// Binaural focus waves: two close tones, one per ear, that the brain hears as a slow 14 Hz (beta) pulse. Needs headphones.
function binaural() {
  const out = bus(1), merger = ctx.createChannelMerger(2), carrier = 200, beat = 14;
  merger.connect(out); ambientNodes.push(merger);
  [carrier, carrier + beat].forEach((freq, ear) => {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.value = freq; g.gain.value = 0.22;
    o.connect(g); g.connect(merger, 0, ear); o.start();
    ambientNodes.push(o, g);
  });
  // A soft drone and low rumble underneath so it feels like a place, not a test tone.
  [[100, 0.05], [150, 0.025]].forEach(([freq, gain]) => {
    const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.value = freq; g.gain.value = gain;
    o.connect(g); g.connect(out); o.start(); ambientNodes.push(o, g);
  });
  loop('brown', 0.25, { type: 'lowpass', freq: 400 });
}

export function setAmbient(kind, volume = 0.6) {
  if (!ensure()) return;
  const t = ctx.currentTime;
  if (kind === current) { ambientGain.gain.setTargetAtTime(kind === 'none' ? 0 : volume, t, 0.2); return; }
  ambientGain.gain.setTargetAtTime(0, t, 0.15);
  stopNodes();
  current = kind;
  if (kind === 'none') return;
  setTimeout(() => {
    if (current !== kind) return;
    if (kind === 'campfire') {
      loop('brown', 0.55, { type: 'lowpass', freq: 600 });
      loop('white', 0.02, { type: 'bandpass', freq: 3000, q: 0.5 });
      every(60, 260, crackle);
    } else if (kind === 'rain') {
      loop('pink', 0.5, { type: 'lowpass', freq: 5000 });
      every(80, 500, drop);
    } else if (kind === 'breeze') {
      const { src } = loop('white', 0.25, { type: 'lowpass', freq: 500 });
      const f = ambientNodes.find((n) => n instanceof BiquadFilterNode);
      const lfo = ctx.createOscillator(), depth = ctx.createGain();
      lfo.frequency.value = 0.07; depth.gain.value = 350; lfo.connect(depth); depth.connect(f.frequency); lfo.start();
      ambientNodes.push(lfo, depth);
      every(5000, 14000, birdSong);
      void src;
    } else if (kind === 'lofi') lofi();
    else if (kind === 'binaural') binaural();
    ambientGain.gain.setTargetAtTime(volume, ctx.currentTime, 0.5);
  }, 400);
}

export function stopAmbient() { setAmbient('none'); }

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
