// Game state and rules. Mirrors EmberGrove/Model/Progression.swift.
import {
  AREAS, LANDMARKS, COMPANIONS, COSMETICS, DECORATIONS, CURIOS, CHAPTERS, ABILITIES,
  ACHIEVEMENTS, QUESTS, RENEWAL_MILESTONES, byId, stageFor,
} from './content.js';

const STORAGE_KEY = 'ember-grove-state-v1';
export const GLOW_PER_MINUTE = 10;
export const MAX_LEVEL = 50;
export const POINTS_PER_HEART = 25;

export function defaultSettings() {
  return {
    defaultMode: 'countdown', defaultMinutes: 25, defaultCategory: 'studying', dailyGoalMinutes: 60,
    ambient: 'campfire', ambientVolume: 0.6, soundEffects: true, keepScreenAwake: true,
    reduceMotion: false, appearance: 'system', hasOnboarded: false,
    pomoFocus: 25, pomoShort: 5, pomoLong: 15, pomoEvery: 4, pomoAuto: false,
    deepFocus: true,
  };
}

export function newState() {
  return {
    version: 1, createdAt: Date.now(), lastModified: Date.now(),
    emberName: 'Ember', xp: 0, seeds: 0, path: null,
    equippedHead: null, equippedNeck: null, equippedFace: null, flameTint: 'amber', purchasedCosmetics: [],
    restored: {}, restoredOrder: [], unlockedAreas: ['clearing'], ownedDecorations: [], hiddenDecorations: [],
    friendship: {}, curios: {}, chapters: {}, chaptersRead: [], achievements: {}, claimedQuests: [],
    sessions: [], journal: [], activeSession: null, settings: defaultSettings(),
    pomo: null, activeBreak: null, pomoSets: 0,
  };
}

export function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const s = JSON.parse(raw);
      return { ...newState(), ...s, settings: { ...defaultSettings(), ...(s.settings || {}) } };
    }
  } catch (e) { /* storage unavailable */ }
  return newState();
}

export function save(s) {
  s.lastModified = Date.now();
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(s)); } catch (e) { /* ignore */ }
}

// ---------- Leveling ----------
export function xpRequired(level) {
  const n = Math.max(1, level) - 1;
  return 100 * n + 20 * n * Math.max(0, n - 1);
}
export function levelFor(xp) {
  let l = 1;
  while (l < MAX_LEVEL && xp >= xpRequired(l + 1)) l++;
  return l;
}
export function levelProgress(xp) {
  const l = levelFor(xp);
  if (l >= MAX_LEVEL) return 1;
  const lo = xpRequired(l), hi = xpRequired(l + 1);
  return (xp - lo) / (hi - lo);
}

// ---------- Derived ----------
export const level = (s) => levelFor(s.xp);
export function stageIndex(s) {
  const l = level(s);
  if (l >= 25 && s.path) return 4;
  if (l >= 15 && s.path) return 3;
  if (l >= 8 && s.path) return 2;
  if (l >= 4) return 1;
  return 0;
}
export const stage = (s) => stageFor(stageIndex(s), s.path);
export const canChoosePath = (s) => !s.path && level(s) >= 8;
export const appearance = (s) => ({
  stage: stageIndex(s), path: s.path, head: s.equippedHead, neck: s.equippedNeck, face: s.equippedFace, flameTint: s.flameTint,
});

export const counted = (s) => s.sessions.filter((r) => r.seconds >= 60);
export const totalMinutes = (s) => Math.floor(s.sessions.reduce((a, r) => a + r.seconds, 0) / 60);
export const renewalsEarned = (s) => RENEWAL_MILESTONES.filter((m) => totalMinutes(s) >= m).length;
export const renewalsAvailable = (s) => Math.max(0, renewalsEarned(s) - Object.keys(s.restored).length);
export const nextRenewal = (s) => RENEWAL_MILESTONES.find((m) => m > totalMinutes(s));
export const hearthLit = (s) => counted(s).length > 0;

export const isAreaUnlocked = (s, id) => s.unlockedAreas.includes(id);
export function isLandmarkVisible(s, l) {
  if (!isAreaUnlocked(s, l.area)) return false;
  if (l.requiresCurio && !s.curios[l.requiresCurio]) return false;
  return true;
}
export function availableLandmarks(s) {
  return LANDMARKS.filter((l) => !s.restored[l.id] && isLandmarkVisible(s, l) && (!l.requiresLandmark || s.restored[l.requiresLandmark]));
}
export function pendingChoices(s) {
  return Math.min(renewalsAvailable(s), availableLandmarks(s).length) + (canChoosePath(s) ? 1 : 0);
}
export function presentCompanions(s) {
  return COMPANIONS.filter((c) => (c.homeLandmark ? !!s.restored[c.homeLandmark] : !!s.chapters[c.arrivesWithChapter]));
}
export const hearts = (s, id) => Math.min(10, Math.floor((s.friendship[id] || 0) / POINTS_PER_HEART));

export function unlockedAbilities(s) {
  const st = stageIndex(s);
  return ABILITIES.filter((a) => a.stage <= st && (!a.path || a.path === s.path));
}
export function bonuses(s) {
  const b = { discovery: 0, seedMult: 1, friendMult: 1, glowMult: 1, minDiscovery: 10 };
  for (const a of unlockedAbilities(s)) {
    switch (a.id) {
      case 'emberSense': b.discovery += 0.05; break;
      case 'wayfinder': b.discovery += 0.10; break;
      case 'steadyFlame': b.seedMult += 0.10; break;
      case 'gentleRain': b.seedMult += 0.15; break;
      case 'hearthSong': case 'greenThumb': b.friendMult += 0.25; break;
      case 'everflame': case 'evergreen': case 'astralTide': b.glowMult += 0.10; break;
      case 'nightSight': b.minDiscovery = 5; break;
    }
  }
  return b;
}

export function isCosmeticUnlocked(s, c) {
  const u = c.unlock;
  if (u.starter) return true;
  if (u.level) return level(s) >= u.level;
  if (u.seeds || u.gift) return s.purchasedCosmetics.includes(c.id);
  if (u.path) return s.path === u.path && stageIndex(s) >= 2;
  if (u.curios) return Object.keys(s.curios).length >= u.curios;
  return false;
}
export const unlockedCosmeticIds = (s) => COSMETICS.filter((c) => isCosmeticUnlocked(s, c)).map((c) => c.id);
export function equipped(s, slot) {
  return { head: s.equippedHead, neck: s.equippedNeck, face: s.equippedFace, flame: s.flameTint }[slot];
}

// ---------- Time helpers ----------
const startOfDay = (d) => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x.getTime(); };
export const sameDay = (a, b) => startOfDay(a) === startOfDay(b);
export function startOfWeek(d) {
  const x = new Date(startOfDay(d));
  const day = (x.getDay() + 6) % 7; // Monday first
  x.setDate(x.getDate() - day);
  return x.getTime();
}
export const dayKey = (d) => { const x = new Date(d); return `${x.getFullYear()}-${x.getMonth() + 1}-${x.getDate()}`; };
export const weekKey = (d) => `W${dayKey(startOfWeek(d))}`;
export const sessionsOnDay = (s, d) => s.sessions.filter((r) => sameDay(r.start, d));
export const sessionsInWeek = (s, d) => { const w = startOfWeek(d); return s.sessions.filter((r) => r.start >= w && r.start < w + 7 * 864e5 + 36e5); };
export const minutesOn = (s, d) => Math.floor(sessionsOnDay(s, d).reduce((a, r) => a + r.seconds, 0) / 60);
export const todayMinutes = (s) => minutesOn(s, Date.now());

// ---------- Random ----------
export function hashString(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
export function seeded(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------- Quests ----------
function metricProgress(metric, records) {
  const mins = (rs) => Math.floor(rs.reduce((a, r) => a + r.seconds, 0) / 60);
  if (metric === 'minutes') return mins(records);
  if (metric === 'sessions') return records.filter((r) => r.seconds >= 60).length;
  if (metric.startsWith('cat:')) return mins(records.filter((r) => r.category === metric.slice(4)));
  if (metric === 'longest') return Math.max(0, ...records.map((r) => Math.floor(r.seconds / 60)));
  if (metric === 'beforeNoon') return records.some((r) => new Date(r.start).getHours() < 12) ? 1 : 0;
  if (metric === 'days') return new Set(records.map((r) => startOfDay(r.start))).size;
  if (metric === 'categories') return new Set(records.map((r) => r.category)).size;
  return 0;
}
export function quests(s, cadence, now = Date.now()) {
  const key = cadence === 'daily' ? dayKey(now) : weekKey(now);
  const rnd = seeded(hashString(key));
  const pool = QUESTS.filter((q) => q.cadence === cadence).map((q) => ({ q, r: rnd() })).sort((a, b) => a.r - b.r).map((x) => x.q);
  const picked = pool.slice(0, cadence === 'daily' ? 3 : 2);
  const records = cadence === 'daily' ? sessionsOnDay(s, now) : sessionsInWeek(s, now);
  return picked.map((t) => {
    const claimKey = `${t.id}@${key}`;
    const progress = metricProgress(t.metric, records);
    return { template: t, progress, claimKey, claimed: s.claimedQuests.includes(claimKey), complete: progress >= t.target };
  });
}
export const claimableQuests = (s) => [...quests(s, 'daily'), ...quests(s, 'weekly')].filter((q) => q.complete && !q.claimed).length;

// ---------- Mutations ----------
export function log(s, text, icon) {
  s.journal.push({ date: Date.now(), text: text.replaceAll('{name}', s.emberName), icon });
  if (s.journal.length > 300) s.journal.shift();
}

export function grant(s, item) {
  if (item.seeds) { s.seeds += item.seeds; return item; }
  if (item.cosmetic) {
    if (s.purchasedCosmetics.includes(item.cosmetic)) { s.seeds += 30; return { seeds: 30 }; }
    s.purchasedCosmetics.push(item.cosmetic); return item;
  }
  if (item.decoration) {
    if (s.ownedDecorations.includes(item.decoration)) { s.seeds += 30; return { seeds: 30 }; }
    s.ownedDecorations.push(item.decoration); return item;
  }
  return item;
}

/** Applies a finished session. Every focused minute counts, even when ending early. */
export function applySession(s, record, now = Date.now(), rnd = Math.random) {
  const summary = {
    record, glowLines: [], glowTotal: 0, seeds: 0,
    levelBefore: level(s), appearanceBefore: appearance(s), newCosmetics: [], companionVisit: null,
    discovery: null, renewalsEarned: 0, milestones: { areas: [], chapters: [], achievements: [], companionsArrived: [] },
  };
  const cosmeticsBefore = new Set(unlockedCosmeticIds(s));
  const renewalsBefore = renewalsEarned(s);
  const bonus = bonuses(s);
  const previousEnd = s.sessions.length ? Math.max(...s.sessions.map((r) => r.end)) : null;
  const minutes = Math.floor(record.seconds / 60);
  s.sessions.push(record);

  const base = minutes * GLOW_PER_MINUTE;
  const lines = [{ label: `${minutes} focused minute${minutes === 1 ? '' : 's'}`, amount: base }];
  if (record.mode === 'countdown' && record.reachedTarget) lines.push({ label: 'Finished your timer', amount: Math.floor(base / 5) });
  else if (record.mode === 'stopwatch' && minutes >= 25) lines.push({ label: 'Long, steady session', amount: Math.floor(base / 10) });
  if (previousEnd && now - previousEnd > 36 * 3600e3) lines.push({ label: 'Welcome back, rested glow', amount: Math.floor(base / 4) });
  if (record.deep && !record.interruptions && minutes >= 10) lines.push({ label: 'Deep Focus, no distractions', amount: Math.floor(base / 10) });
  if (bonus.glowMult > 1) lines.push({ label: `${stage(s).name}'s radiance`, amount: Math.floor(base * (bonus.glowMult - 1)) });
  summary.glowLines = lines;
  summary.glowTotal = lines.reduce((a, l) => a + l.amount, 0);
  s.xp += summary.glowTotal;

  summary.seeds = Math.round(Math.max(1, Math.floor(minutes / 5)) * bonus.seedMult);
  s.seeds += summary.seeds;

  const present = presentCompanions(s).filter((c) => hearts(s, c.id) < 10);
  if (minutes >= 5 && present.length) {
    const weights = present.map((c) => 11 - hearts(s, c.id));
    let roll = rnd() * weights.reduce((a, b) => a + b, 0);
    let chosen = present[0];
    for (let i = 0; i < present.length; i++) { if (roll < weights[i]) { chosen = present[i]; break; } roll -= weights[i]; }
    const before = hearts(s, chosen.id);
    s.friendship[chosen.id] = (s.friendship[chosen.id] || 0) + Math.round(minutes * bonus.friendMult);
    const after = hearts(s, chosen.id);
    const gifts = [], memories = [];
    for (let h = before + 1; h <= after; h++) {
      if (chosen.gifts[h]) gifts.push(grant(s, chosen.gifts[h]));
      if (chosen.memories[h]) { memories.push(chosen.memories[h]); log(s, chosen.memories[h], 'heart'); }
    }
    summary.companionVisit = { companion: chosen.id, heartsBefore: before, heartsAfter: after, gifts, memories };
  }

  if (minutes >= bonus.minDiscovery) {
    const chance = Math.min(0.75, 0.12 + minutes * 0.01 + bonus.discovery);
    if (rnd() < chance) {
      const candidates = CURIOS.filter((c) => !s.curios[c.id] && isAreaUnlocked(s, c.area));
      const pick = candidates.find((c) => c.id === 'starMap') || candidates[Math.floor(rnd() * candidates.length)];
      if (pick) { s.curios[pick.id] = now; summary.discovery = pick.id; log(s, `Found something in the grove: ${pick.name}.`, pick.icon); }
    }
  }

  if (counted(s).length === 1) log(s, '{name} lit the hearth for the first time.', 'flame');
  summary.levelAfter = level(s);
  summary.appearanceAfter = appearance(s);
  summary.evolved = summary.appearanceAfter.stage !== summary.appearanceBefore.stage;
  if (summary.evolved) log(s, `{name} grew into a ${stage(s).name}!`, 'sparkles');
  summary.newCosmetics = unlockedCosmeticIds(s).filter((id) => !cosmeticsBefore.has(id));
  summary.renewalsEarned = renewalsEarned(s) - renewalsBefore;
  summary.milestones = refreshMilestones(s);
  summary.questsReady = claimableQuests(s);
  return summary;
}

export function restore(s, landmarkId, variantId) {
  const l = byId(LANDMARKS, landmarkId);
  if (!l || renewalsAvailable(s) <= 0 || !availableLandmarks(s).includes(l)) return null;
  s.restored[l.id] = variantId;
  s.restoredOrder.push(l.id);
  log(s, `Restored ${l.name} with ${byId(l.variants, variantId)?.name || ''}.`, 'leaf');
  if (l.companion) log(s, `${byId(COMPANIONS, l.companion).name} moved in.`, 'paw');
  return refreshMilestones(s);
}

export function choosePath(s, path) {
  if (!canChoosePath(s)) return null;
  s.path = path;
  const tint = COSMETICS.find((c) => c.unlock.path === path);
  if (tint) s.flameTint = tint.id;
  log(s, `{name} chose the path of ${path[0].toUpperCase() + path.slice(1)} and became a ${stage(s).name}.`, 'branch');
  return refreshMilestones(s);
}

export function claim(s, q) {
  if (!q.complete || s.claimedQuests.includes(q.claimKey)) return false;
  s.claimedQuests.push(q.claimKey);
  s.seeds += q.template.seeds;
  s.xp += q.template.glow;
  return true;
}

export function buyCosmetic(s, c) {
  if (!c.unlock.seeds || s.seeds < c.unlock.seeds || s.purchasedCosmetics.includes(c.id)) return false;
  s.seeds -= c.unlock.seeds;
  s.purchasedCosmetics.push(c.id);
  return true;
}

export function buyDecoration(s, d) {
  if (s.seeds < d.cost || s.ownedDecorations.includes(d.id)) return false;
  s.seeds -= d.cost;
  s.ownedDecorations.push(d.id);
  log(s, `Added ${d.name} to the clearing.`, 'house');
  return true;
}

export function equip(s, cosmetic, slot) {
  if (cosmetic && !isCosmeticUnlocked(s, cosmetic)) return;
  const id = cosmetic ? cosmetic.id : null;
  if (slot === 'head') s.equippedHead = id;
  if (slot === 'neck') s.equippedNeck = id;
  if (slot === 'face') s.equippedFace = id;
  if (slot === 'flame') s.flameTint = id || 'amber';
}

function isTriggered(s, t) {
  if (t.start) return true;
  if (t.firstSession) return counted(s).length > 0;
  if (t.firstRestoration) return Object.keys(s.restored).length > 0;
  if (t.area) return isAreaUnlocked(s, t.area);
  if (t.pathChosen) return !!s.path;
  if (t.landmark) return !!s.restored[t.landmark];
  if (t.curio) return !!s.curios[t.curio];
  if (t.allRestored) return Object.keys(s.restored).length >= LANDMARKS.length;
  return false;
}

function isEarned(s, id) {
  const c = counted(s);
  const mins = totalMinutes(s);
  switch (id) {
    case 'firstSpark': return c.length > 0;
    case 'hourOfGlow': return mins >= 60;
    case 'tenHours': return mins >= 600;
    case 'fiftyHours': return mins >= 3000;
    case 'hundredHours': return mins >= 6000;
    case 'deepDive': return c.some((r) => r.seconds >= 3600);
    case 'earlyBird': return c.some((r) => new Date(r.start).getHours() < 8);
    case 'nightOwl': return c.some((r) => new Date(r.end).getHours() >= 22);
    case 'wellRounded': return new Set(c.map((r) => r.category)).size >= 4;
    case 'steadyWeek': {
      const weeks = {};
      for (const r of c) (weeks[weekKey(r.start)] ||= new Set()).add(startOfDay(r.start));
      return Object.values(weeks).some((d) => d.size >= 5);
    }
    case 'pathfinder': return !!s.path;
    case 'elder': return stageIndex(s) >= 4;
    case 'restorer': return Object.keys(s.restored).length >= 6;
    case 'explorer': return s.unlockedAreas.length >= AREAS.length;
    case 'trueFriend': return COMPANIONS.some((cp) => hearts(s, cp.id) >= 10);
    case 'collector': return Object.keys(s.curios).length >= 12;
    case 'rekindled': return Object.keys(s.restored).length >= LANDMARKS.length;
    case 'fullCycle': return (s.pomoSets || 0) >= 1;
  }
  return false;
}

export function refreshMilestones(s) {
  const ch = { areas: [], chapters: [], achievements: [], companionsArrived: [] };
  const mins = totalMinutes(s);
  for (const a of AREAS) {
    if (!s.unlockedAreas.includes(a.id) && mins >= a.unlockMinutes) {
      s.unlockedAreas.push(a.id); ch.areas.push(a.id); log(s, `The frost lifted from ${a.name}.`, 'map');
    }
  }
  const before = new Set(presentCompanions(s).map((c) => c.id));
  for (const c of CHAPTERS) {
    if (!s.chapters[c.id] && isTriggered(s, c.trigger)) { s.chapters[c.id] = Date.now(); ch.chapters.push(c.id); }
  }
  ch.companionsArrived = presentCompanions(s).map((c) => c.id).filter((id) => !before.has(id));
  for (const id of ch.companionsArrived) {
    const c = byId(COMPANIONS, id);
    if (!c.homeLandmark) log(s, `${c.name} the ${c.species.toLowerCase()} arrived at the hearth.`, 'paw');
  }
  for (const a of ACHIEVEMENTS) {
    if (!s.achievements[a.id] && isEarned(s, a.id)) { s.achievements[a.id] = Date.now(); ch.achievements.push(a.id); }
  }
  return ch;
}

// ---------- Focus session (date-based, survives the app being closed) ----------
export function elapsed(a, now = Date.now()) {
  const end = a.pausedAt ?? now;
  let e = (end - a.startDate) / 1000 - a.pausedTotal;
  if (a.target) e = Math.min(e, a.target);
  return Math.max(0, e);
}
export const remaining = (a, now = Date.now()) => (a.target ? Math.max(0, a.target - elapsed(a, now)) : null);
export const progress = (a, now = Date.now()) => (a.target ? elapsed(a, now) / a.target : null);
export const endDate = (a) => (a.target && !a.pausedAt ? a.startDate + (a.pausedTotal + a.target) * 1000 : null);
export const isComplete = (a, now = Date.now()) => !!a.target && elapsed(a, now) >= a.target - 0.5;

export { AREAS, LANDMARKS, COMPANIONS, COSMETICS, DECORATIONS, CURIOS, CHAPTERS, ABILITIES, ACHIEVEMENTS, byId, stageFor };
