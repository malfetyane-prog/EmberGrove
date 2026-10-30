import * as G from './game.js';
import {
  CATEGORIES, AMBIENCE, PATHS, FLAMES, AREAS, LANDMARKS, COMPANIONS, COSMETICS, DECORATIONS, CURIOS, CHAPTERS,
  ABILITIES, ACHIEVEMENTS, RENEWAL_MILESTONES, byId, stageFor,
} from './content.js';
import { drawEmber } from './ember.js';
import { drawGrove, drawCompanion, skyPhase, groundY, WORLD_W, WORLD_H, COMPANION_FRAMES } from './grove.js';
import * as Sound from './audio.js';
import { icon } from './icons.js';

// ---------------------------------------------------------------- state
let S = G.load();
G.refreshMilestones(S);
G.save(S);

const ui = {
  tab: 'home', sheet: null, dialog: null, banner: null, reward: null, revealed: 0, revealTimer: null, glowStart: 0,
  mood: 'idle', speech: null, worldX: 322, worldTarget: 322, worldMood: 'idle', journey: 'quests', slot: 'head',
  onboardStep: 0, setup: null, restorePick: null, restoreVariant: null, pathPick: 'hearth', chapterPage: 0, scroll: {},
};
let snap = null;
const $app = document.getElementById('app'), $layer = document.getElementById('layer');

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const nm = () => esc(S.emberName);
const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;
const fmtMin = (m) => (m < 60 ? `${m}m` : m % 60 === 0 ? `${Math.floor(m / 60)}h` : `${Math.floor(m / 60)}h ${m % 60}m`);
function fmtDur(sec) {
  const t = Math.max(0, Math.floor(sec)), h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60;
  const p = (n) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${p(m)}:${p(s)}` : `${p(m)}:${p(s)}`;
}
const reduceMotion = () => S.settings.reduceMotion || matchMedia('(prefers-reduced-motion: reduce)').matches;
const sfx = (n) => Sound.play(n, S.settings.soundEffects);
const isStandalone = () => navigator.standalone === true || matchMedia('(display-mode: standalone)').matches;

function makeSnap() {
  snap = {
    restored: S.restored, unlockedAreas: S.unlockedAreas, curios: S.curios, hearthLit: G.hearthLit(S),
    decorations: S.ownedDecorations.filter((d) => !S.hiddenDecorations.includes(d)),
    companions: G.presentCompanions(S).map((c) => c.id),
  };
}

function commit(fn) {
  const result = fn ? fn(S) : undefined;
  G.save(S);
  render();
  return result;
}

function applyTheme() {
  const a = S.settings.appearance;
  if (a === 'system') delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = a;
}

// ---------------------------------------------------------------- canvas markup
const json = (o) => esc(JSON.stringify(o));
function emberCv(a, mood, size, anim = true, extra = '') {
  return `<canvas data-kind="ember" data-a="${json(a)}" data-mood="${mood}" data-anim="${anim ? 1 : 0}" style="width:${size}px;height:${size}px;${extra}"></canvas>`;
}
const companionCv = (id, size) => `<canvas data-kind="companion" data-id="${id}" style="width:${size}px;height:${size}px"></canvas>`;

// ---------------------------------------------------------------- render
function render() {
  makeSnap();
  applyTheme();
  const scr = $app.querySelector('.screen');
  if (scr) ui.scroll[scr.dataset.tab] = scr.scrollTop;
  const map = $app.querySelector('.map');
  if (map) ui.scroll.map = map.scrollLeft;
  const sb = $layer.querySelector('.sheet-body');
  if (sb) ui.scroll.sheet = sb.scrollTop;

  const screens = { home: renderHome, world: renderWorld, ember: renderEmber, journey: renderJourney, stats: renderStats };
  $app.innerHTML = `<div style="position:relative;flex:1;display:flex;min-height:0">${screens[ui.tab]()}</div>${renderTabbar()}`;
  const ns = $app.querySelector('.screen');
  if (ns) ns.scrollTop = ui.scroll[ui.tab] || 0;
  const nm2 = $app.querySelector('.map');
  if (nm2) nm2.scrollLeft = ui.scroll.map || 0;
  renderLayer();
}

function renderLayer() {
  const sb = $layer.querySelector('.sheet-body');
  const keep = sb ? sb.scrollTop : 0;
  let html = '';
  if (!S.settings.hasOnboarded) html += renderOnboarding();
  else if (ui.reward) html += renderReward();
  else if (S.activeSession) html += renderFocus();
  else if (S.activeBreak) html += renderBreak();
  if (ui.sheet) html += `<div class="backdrop" data-act="closeSheet"></div>${renderSheet()}`;
  if (ui.dialog) html += renderDialog();
  if (ui.banner) html += `<div class="banner" data-act="dismissBanner"><span style="color:var(--amber)">${icon(ui.banner.icon, 24)}</span><div><div class="label">${esc(ui.banner.title)}</div><div class="small soft">${esc(ui.banner.sub)}</div></div></div>`;
  $layer.innerHTML = html;
  const nsb = $layer.querySelector('.sheet-body');
  if (nsb) nsb.scrollTop = keep || ui.scroll.sheet || 0;
  drawNow();
}

/** Paints freshly created canvases immediately so re-renders never flash blank. */
function drawNow() {
  if (!snap) return;
  const t = (performance.now() / 1000) % 3600, still = reduceMotion();
  for (const c of document.querySelectorAll('canvas[data-kind]')) if (!c.dataset.drawn) drawCanvas(c, t, still);
}

function renderTabbar() {
  const tabs = [
    ['home', 'flame', 'Hearth', 0], ['world', 'tree', 'Grove', G.canChoosePath(S) ? 0 : Math.min(G.renewalsAvailable(S), G.availableLandmarks(S).length)],
    ['ember', 'sparkles', S.emberName, G.canChoosePath(S) ? '!' : 0], ['journey', 'book', 'Journey', G.claimableQuests(S)], ['stats', 'chart', 'Stats', 0],
  ];
  return `<nav class="tabbar">${tabs.map(([id, ic, label, badge]) => `<button class="${ui.tab === id ? 'on' : ''}" data-act="tab" data-arg="${id}" aria-label="${esc(label)}">
    ${icon(ic, 24)}<span>${esc(label)}</span>${badge ? `<span class="dot">${badge}</span>` : ''}</button>`).join('')}</nav>`;
}

const bar = (v, color = 'var(--amber)', thin = false) => `<div class="bar ${thin ? 'thin' : ''}" style="--c:${color}"><i style="width:${Math.max(0, Math.min(1, v)) * 100}%"></i></div>`;
const seedPill = () => `<span class="pill" style="color:var(--seeds)"><span class="seed"></span>${S.seeds}</span>`;
const heartsRow = (n, size = 12) => `<span class="row" style="gap:2px">${Array.from({ length: 10 }, (_, i) => `<span style="color:${i < n ? 'var(--coral)' : 'var(--line)'}">${icon(i < n ? 'heart' : 'heartOutline', size)}</span>`).join('')}</span>`;

// ---------------------------------------------------------------- Home
function greeting() {
  const h = new Date().getHours();
  return h >= 5 && h < 12 ? 'Good morning' : h < 17 && h >= 12 ? 'Good afternoon' : h >= 17 && h < 22 ? 'Good evening' : 'A quiet night';
}

function renderHome() {
  const st = G.stage(S), today = G.todayMinutes(S), goal = S.settings.dailyGoalMinutes, lvl = G.level(S);
  const ringV = Math.min(1, today / Math.max(1, goal)), next = G.nextRenewal(S), tm = G.totalMinutes(S);
  const prev = [...RENEWAL_MILESTONES].reverse().find((m) => m <= tm) || 0;
  const set = S.settings;
  const vp = [40, 500], yTop = 150;
  return `<div class="screen with-cta" data-tab="home"><div class="stack">
    <div class="row" style="padding-top:4px">
      <div><div class="small soft">${greeting()}</div><div class="row" style="gap:8px"><span class="title">${nm()}</span><span class="badge-level">Lv ${lvl}</span></div></div>
      <span class="spacer"></span>${seedPill()}
      <button data-act="openSheet" data-arg="settings" aria-label="Settings" style="width:44px;height:44px;display:grid;place-items:center;color:var(--ink-soft)">${icon('gear', 24)}</button>
    </div>
    <div class="scene" style="aspect-ratio:${vp[1] - vp[0]}/${600 - yTop}" data-act="pokeEmber">
      <canvas data-kind="grove" data-live="home" data-vp="${vp}" data-ytop="${yTop}" data-es="150"></canvas>
      ${ui.speech ? `<div class="speech">${esc(ui.speech)}</div>` : ''}
      <div class="scene-tags"><span class="glass">${esc(st.name)}</span><span class="glass">${Object.keys(S.restored).length}/${LANDMARKS.length} restored</span></div>
    </div>
    ${!isStandalone() && !set.hideInstallTip ? `<div class="card row" style="gap:12px;align-items:flex-start">
      <span style="color:var(--amber)">${icon('share', 26)}</span>
      <div class="spacer"><div class="label">Add Ember Grove to your Home Screen</div><div class="small soft">In Safari, tap <b>Share</b>, then <b>Add to Home Screen</b>. It then opens full-screen like an app. Your progress is saved separately in Safari and in the Home Screen app, so pick one and stick with it.</div></div>
      <button data-act="hideInstallTip" aria-label="Dismiss" class="soft">${icon('close', 18)}</button></div>` : ''}
    ${choiceCards()}
    <div class="card row" style="gap:18px">
      <div class="ring" role="img" aria-label="Focused ${today} of ${goal} minutes today">
        <svg width="86" height="86"><circle cx="43" cy="43" r="38" fill="none" stroke="var(--line)" stroke-width="10"/>
        <circle cx="43" cy="43" r="38" fill="none" stroke="var(--amber)" stroke-width="10" stroke-linecap="round" stroke-dasharray="${238.8 * ringV} 240"/></svg>
        <div class="lbl"><b style="font-size:18px">${fmtMin(today)}</b><span class="tiny soft">today</span></div>
      </div>
      <div class="spacer stack" style="gap:10px">
        <div><div class="row"><span class="label">Level ${lvl}</span><span class="spacer"></span><span class="small soft">${G.xpRequired(lvl + 1) - S.xp} Glow to go</span></div>${bar(G.levelProgress(S.xp))}</div>
        ${next ? `<div><div class="row"><span class="label">Next restoration</span><span class="spacer"></span><span class="small soft">${fmtMin(next - tm)} of focus</span></div>${bar((tm - prev) / Math.max(1, next - prev), 'var(--moss)', true)}</div>` : ''}
      </div>
    </div>
    <div class="card stack" style="gap:12px">
      <div class="row"><span class="h2" style="font-size:17px">Today's quests</span><span class="spacer"></span><button class="label" style="color:var(--amber)" data-act="tab" data-arg="journey">See all</button></div>
      ${G.quests(S, 'daily').map((q) => `<div class="row"><span style="color:${q.complete ? 'var(--amber)' : 'var(--ink-soft)'}">${icon(q.claimed ? 'check' : q.complete ? 'gift' : 'clock', 20)}</span>
        <span class="spacer" style="${q.claimed ? 'text-decoration:line-through;opacity:.6' : ''}">${esc(q.template.title)}</span><span class="small soft">${Math.min(q.progress, q.template.target)}/${q.template.target}</span></div>`).join('')}
    </div>
  </div></div>
  <div class="cta">
    <button class="btn" data-act="openSheet" data-arg="setup">${icon('flame', 22)} ${S.activeSession || S.activeBreak ? 'Return to focus' : 'Begin focusing'}</button>
    <div class="center tiny soft" style="margin-top:6px">${set.defaultMode === 'countdown' ? `${set.defaultMinutes} min` : set.defaultMode === 'pomodoro' ? `Pomodoro ${set.pomoFocus}/${set.pomoShort}` : 'Stopwatch'} · ${CATEGORIES[set.defaultCategory].title}</div>
  </div>`;
}

function choiceCards() {
  let h = '';
  if (G.canChoosePath(S)) h += choiceCard('sparkles', `${nm()} is ready to evolve`, 'Choose a path: Hearth, Bloom or Starlight', 'path');
  const r = G.renewalsAvailable(S);
  if (r > 0 && G.availableLandmarks(S).length) h += choiceCard('leaf', 'The grove is ready to change', `${plural(r, 'restoration')} to choose`, 'restore');
  return h;
}
const choiceCard = (ic, title, sub, sheet) => `<button class="choice" data-act="openSheet" data-arg="${sheet}"><span class="orb">${icon(ic, 24)}</span>
  <span class="spacer"><div class="label">${title}</div><div class="small soft">${sub}</div></span><span class="soft">${icon('chevron', 18)}</span></button>`;

function chatter() {
  let o = ['I kept the fire warm for you.', 'Shall we focus together?', 'The grove feels different lately. Brighter.', "I like it when you're here.", 'Every minute counts. Even small ones.'];
  if (G.canChoosePath(S)) o = ["I feel… different. Like I'm about to change!"];
  else if (G.renewalsAvailable(S) > 0 && G.availableLandmarks(S).length) o.push('We could fix something in the grove! Want to choose?');
  if (G.todayMinutes(S) === 0) o.push('A short session is a lovely way to start.');
  if (G.todayMinutes(S) >= S.settings.dailyGoalMinutes) o.push('You did so much today. Rest is good too.');
  const friends = G.presentCompanions(S);
  if (friends.length) o.push(`${friends[Math.floor(Math.random() * friends.length)].name} was asking about you.`);
  const h = new Date().getHours();
  if (h >= 22 || h < 5) o.push("It's late. Maybe one more short one, then sleep?");
  return o[Math.floor(Math.random() * o.length)];
}

// ---------------------------------------------------------------- World
const MAP_H = 420, MAP_S = MAP_H / WORLD_H, MAP_W = WORLD_W * MAP_S;
const HOT = { oldOak: [260, 300], treehouse: [100, 90], meadow: [150, 100], lilyPond: [150, 100], mushroomRing: [150, 100], fireflyHollow: [150, 100], moonflowers: [150, 100], willowBridge: [150, 100] };

function renderWorld() {
  const r = G.renewalsAvailable(S), avail = G.availableLandmarks(S).length;
  return `<div class="screen" data-tab="world"><div class="stack">
    <div class="row"><span class="title">The Grove</span><span class="spacer"></span>${seedPill()}</div>
    <div class="map"><div class="map-inner" style="width:${MAP_W}px">
      <canvas data-kind="grove" data-live="world" data-vp="0,${WORLD_W}" data-es="120"></canvas>
      ${LANDMARKS.filter((l) => G.isLandmarkVisible(S, l) && (!l.requiresLandmark || S.restored[l.requiresLandmark])).map((l) => {
        const [w, h] = HOT[l.id] || [100, 100];
        return `<button class="hot" data-act="visit" data-arg="${l.id}" aria-label="${esc(l.name)}" style="left:${l.x * MAP_S}px;top:${(l.y - h / 2 + 10) * MAP_S}px;width:${w * MAP_S}px;height:${h * MAP_S}px"></button>`;
      }).join('')}
      ${AREAS.filter((a) => !G.isAreaUnlocked(S, a.id)).map((a) => `<div class="locked-tag" style="left:${((a.xStart + a.xEnd) / 2) * MAP_S}px;top:${MAP_H * 0.42}px">
        ${icon('lock', 20)}<div class="label">${esc(a.name)}</div><div class="small soft">Opens at ${fmtMin(a.unlockMinutes)} of focus</div></div>`).join('')}
    </div></div>
    <div class="small soft center">Swipe to explore · tap a place to visit it</div>
    ${r > 0 && avail ? `<button class="btn" data-act="openSheet" data-arg="restore">${icon('leaf', 20)} Restore something (${r} available)</button>` : ''}
    <div class="card stack" style="gap:14px"><div class="h2" style="font-size:18px">Regions</div>
      ${AREAS.map((a) => {
        const ls = LANDMARKS.filter((l) => l.area === a.id), done = ls.filter((l) => S.restored[l.id]).length, open = G.isAreaUnlocked(S, a.id);
        return `<div><div class="row"><span style="color:${open ? 'var(--moss)' : 'var(--ink-soft)'}">${icon(open ? 'map' : 'lock', 18)}</span><span class="label">${esc(a.name)}</span><span class="spacer"></span>
          <span class="small soft">${open ? `${done}/${ls.length}` : `${fmtMin(Math.max(0, a.unlockMinutes - G.totalMinutes(S)))} to go`}</span></div>
          <div style="margin-top:6px">${bar(open ? done / ls.length : G.totalMinutes(S) / a.unlockMinutes, open ? 'var(--moss)' : 'var(--ink-soft)', true)}</div></div>`;
      }).join('')}
    </div>
    <button class="btn secondary" data-act="openSheet" data-arg="decor">${icon('palette', 20)} Decorate the clearing</button>
  </div></div>`;
}

// ---------------------------------------------------------------- Ember (character)
function renderEmber() {
  const a = G.appearance(S), st = G.stage(S), lvl = G.level(S), tint = FLAMES[S.flameTint] || FLAMES.amber;
  return `<div class="screen" data-tab="ember"><div class="stack">
    <div class="row"><span class="spacer"></span>${seedPill()}</div>
    <div class="stack center" style="gap:6px;align-items:center">
      <div data-act="pokeEmber" style="width:240px;height:240px;border-radius:50%;background:radial-gradient(circle, ${tint.glow}88, transparent 70%);display:grid;place-items:center">${emberCv(a, ui.mood, 220)}</div>
      <div class="row" style="gap:8px"><span class="title">${nm()}</span><button data-act="rename" class="soft" aria-label="Rename">${icon('pencil', 22)}</button></div>
      <div class="label soft">${esc(st.name)}${S.path ? ` · Path of ${PATHS[S.path].title}` : ''}</div>
      <p class="small soft" style="max-width:320px">${esc(st.blurb)}</p>
      <div style="width:100%;margin-top:8px">${bar(G.levelProgress(S.xp))}<div class="row small soft" style="margin-top:4px"><b>Level ${lvl}</b><span class="spacer"></span>${S.xp} Glow</div></div>
    </div>
    ${G.canChoosePath(S) ? `<button class="btn" data-act="openSheet" data-arg="path">${icon('sparkles', 20)} ${nm()} is ready to evolve</button>` : ''}
    <div class="card stack" style="gap:12px"><div><div class="h2">Evolution</div>${S.path ? '' : '<div class="small soft">At level 8, choose one of three paths.</div>'}</div>
      <div class="row" style="overflow-x:auto;gap:12px;align-items:flex-start;padding-bottom:4px">${[0, 1, 2, 3, 4].map(stageCell).join('')}</div></div>
    <div class="card stack" style="gap:10px"><div class="h2">Abilities</div>
      ${ABILITIES.filter((ab) => !ab.path || ab.path === S.path).map((ab) => {
        const on = G.unlockedAbilities(S).includes(ab);
        return `<div class="row" style="opacity:${on ? 1 : 0.7}"><span class="orb-sm" style="background:${on ? 'color-mix(in srgb,var(--amber-glow) 35%,transparent)' : 'color-mix(in srgb,var(--line) 50%,transparent)'};color:${on ? 'var(--amber)' : 'var(--ink-soft)'}">${icon(on ? 'flame' : 'lock', 16)}</span>
          <div><div class="label">${esc(ab.name)}</div><div class="small soft">${on ? esc(ab.blurb) : `Unlocks as a ${esc(stageFor(ab.stage, ab.path || S.path).name)}`}</div></div></div>`;
      }).join('')}</div>
    <div class="card stack" style="gap:12px"><div class="h2">Wardrobe</div>
      <div class="seg">${['head', 'neck', 'face', 'flame'].map((s) => `<button class="${ui.slot === s ? 'on' : ''}" data-act="slot" data-arg="${s}">${s[0].toUpperCase() + s.slice(1)}</button>`).join('')}</div>
      <div class="grid3">${ui.slot !== 'flame' ? wardrobeTile(null) : ''}${COSMETICS.filter((c) => c.slot === ui.slot).map(wardrobeTile).join('')}</div></div>
    <div class="card stack" style="gap:12px"><div><div class="h2">Memories</div><div class="small soft">${nm()}'s story so far</div></div>
      ${S.journal.length ? S.journal.slice(-25).reverse().map((j) => `<div class="row" style="align-items:flex-start"><span class="orb-sm" style="background:color-mix(in srgb,var(--amber-glow) 25%,transparent);color:var(--amber)">${icon(j.icon, 14)}</span>
        <div><div class="small">${esc(j.text)}</div><div class="tiny soft">${new Date(j.date).toLocaleString([], { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}</div></div></div>`).join('')
        : '<div class="small soft">Nothing yet. The first memory begins with your first focus session.</div>'}</div>
  </div></div>`;
}

function stageCell(i) {
  const reached = G.stageIndex(S) >= i, known = i < 2 || !!S.path, st = stageFor(i, S.path || 'hearth');
  const look = { ...G.appearance(S), stage: i, path: i >= 2 ? S.path || 'hearth' : null };
  return `<div class="center" style="width:84px;flex:none" aria-label="${known ? esc(st.name) : 'Unknown form'}, level ${st.minLevel}">
    <div style="width:78px;height:78px;margin:0 auto;border-radius:50%;position:relative;background:${reached ? 'color-mix(in srgb,var(--amber-glow) 35%,transparent)' : 'color-mix(in srgb,var(--line) 40%,transparent)'};display:grid;place-items:center">
      ${emberCv(look, 'idle', 66, false, reached ? '' : 'filter:brightness(0);opacity:.25')}
      ${known ? '' : '<b style="position:absolute;font-size:26px;color:var(--ink-soft)">?</b>'}</div>
    <div class="small" style="font-weight:700">${known ? esc(st.name) : '???'}</div><div class="tiny soft">Lv ${st.minLevel}</div></div>`;
}

function unlockHint(c) {
  const u = c.unlock;
  if (u.level) return `Level ${u.level}`;
  if (u.seeds) return `${u.seeds} Seeds`;
  if (u.gift) return `Gift from ${byId(COMPANIONS, u.gift).name}`;
  if (u.path) return `${PATHS[u.path].title} path`;
  if (u.curios) return `${u.curios} curios`;
  return '';
}

function wardrobeTile(c) {
  const slot = ui.slot, unlocked = !c || G.isCosmeticUnlocked(S, c), on = G.equipped(S, slot) === (c ? c.id : null);
  const look = { ...G.appearance(S) };
  if (slot === 'flame') look.flameTint = c ? c.id : 'amber'; else look[slot] = c ? c.id : null;
  return `<button class="tile ${on ? 'on' : ''}" data-act="wear" data-arg="${c ? c.id : ''}">
    <div style="position:relative">${emberCv(look, 'idle', 70, false, unlocked ? '' : 'opacity:.35')}${unlocked ? '' : `<span style="position:absolute;top:0;right:0" class="soft">${icon('lock', 14)}</span>`}</div>
    <div class="small" style="font-weight:650">${c ? esc(c.name) : 'None'}</div>
    <div class="tiny" style="color:${on ? 'var(--amber)' : 'var(--ink-soft)'}">${unlocked ? (on ? 'Wearing' : '&nbsp;') : esc(unlockHint(c))}</div></button>`;
}

// ---------------------------------------------------------------- Journey
function renderJourney() {
  const secs = [['quests', 'Quests'], ['story', 'Story'], ['friends', 'Friends'], ['curios', 'Curios'], ['feats', 'Feats']];
  const body = { quests: journeyQuests, story: journeyStory, friends: journeyFriends, curios: journeyCurios, feats: journeyFeats }[ui.journey]();
  return `<div class="screen" data-tab="journey"><div class="stack">
    <div class="title">Journey</div>
    <div class="seg">${secs.map(([id, l]) => `<button class="${ui.journey === id ? 'on' : ''}" data-act="journey" data-arg="${id}">${l}</button>`).join('')}</div>
    ${body}</div></div>`;
}

function questGroup(title, sub, list) {
  return `<div class="card stack" style="gap:14px"><div><div class="h2">${title}</div><div class="small soft">${sub}</div></div>
    ${list.map((q) => `<div><div class="row"><div class="spacer"><div class="label">${esc(q.template.title)}</div>
      <div class="small soft row" style="gap:8px"><span class="row" style="gap:3px"><span class="seed"></span>${q.template.seeds}</span><span>${icon('flame', 13)} ${q.template.glow} Glow</span></div></div>
      ${q.claimed ? `<span class="small" style="color:var(--moss);font-weight:700">${icon('check', 16)} Claimed</span>`
        : q.complete ? `<button class="btn small-btn" data-act="claim" data-arg="${esc(q.claimKey)}">Claim</button>`
        : `<span class="small soft">${q.progress}/${q.template.target}</span>`}</div>
      <div style="margin-top:8px">${bar(q.progress / q.template.target, q.complete ? 'var(--moss)' : 'var(--amber)', true)}</div></div>`).join('')}</div>`;
}
const journeyQuests = () => `${questGroup('Today', 'New quests every morning', G.quests(S, 'daily'))}
  ${questGroup('This week', 'Bigger goals, bigger rewards', G.quests(S, 'weekly'))}
  <p class="small soft center">Quests are always optional. Nothing is lost if you skip a day: the grove just waits for you.</p>`;

function chapterHint(t) {
  if (t.firstSession) return 'Complete your first session';
  if (t.firstRestoration) return 'Restore your first place';
  if (t.area) return `Reach ${byId(AREAS, t.area).name}`;
  if (t.pathChosen) return `Choose ${S.emberName}'s path`;
  if (t.landmark) return `Restore ${byId(LANDMARKS, t.landmark).name}`;
  if (t.curio) return 'Find something hidden on the ridge';
  if (t.allRestored) return 'Restore the whole grove';
  return '';
}
const journeyStory = () => CHAPTERS.map((c) => {
  const open = !!S.chapters[c.id], read = S.chaptersRead.includes(c.id);
  return `<button class="list-row" ${open ? `data-act="readChapter" data-arg="${c.id}"` : 'disabled'} style="width:100%;text-align:left;border:1px solid var(--line)">
    <span style="width:44px;height:44px;border-radius:50%;display:grid;place-items:center;font-weight:800;font-size:19px;flex:none;background:${open ? 'var(--amber-glow)' : 'color-mix(in srgb,var(--line) 50%,transparent)'};color:${open ? 'var(--ink-fixed)' : 'var(--ink-soft)'}">${c.number}</span>
    <span class="spacer"><div class="label">${open ? esc(c.title) : 'A chapter yet to come'}</div>
    <div class="small" style="color:${open && !read ? 'var(--amber)' : 'var(--ink-soft)'}">${open ? (read ? 'Read' : 'New') : esc(chapterHint(c.trigger))}</div></span>
    ${open ? `<span class="soft">${icon('chevron', 18)}</span>` : ''}</button>`;
}).join('');

const journeyFriends = () => COMPANIONS.map((c) => {
  const here = G.presentCompanions(S).includes(c), h = G.hearts(S, c.id);
  const hint = c.homeLandmark ? `Might appear if ${byId(LANDMARKS, c.homeLandmark).name} is restored` : 'Arrives as the story unfolds';
  return `<div class="card stack" style="gap:10px"><div class="row" style="gap:14px">
    <div style="width:64px;height:64px;border-radius:50%;background:color-mix(in srgb,var(--amber-glow) ${here ? 30 : 10}%,transparent);${here ? '' : 'filter:brightness(0);opacity:.25'}">${companionCv(c.id, 64)}</div>
    <div><div class="h2" style="font-size:18px">${here ? esc(c.name) : '???'}</div><div class="small soft">${here ? esc(c.species) : esc(hint)}</div>${here ? heartsRow(h, 11) : ''}</div></div>
    ${here ? `<p class="small soft">${esc(c.blurb)}</p>${Object.keys(c.memories).map(Number).filter((k) => k <= h).map((k) => `<p class="small serif" style="font-style:italic">“${esc(c.memories[k])}”</p>`).join('')}
      ${h < 10 ? '<p class="tiny soft">Friends keep you company during sessions of 5 minutes or more.</p>' : ''}` : ''}</div>`;
}).join('');

const journeyCurios = () => `<div class="card stack" style="gap:14px"><div><div class="h2">Curio cabinet</div><div class="small soft">${Object.keys(S.curios).length} of ${CURIOS.length} found. Longer sessions find more.</div></div>
  <div class="grid3">${CURIOS.map((c) => { const f = !!S.curios[c.id]; return `<button class="stack center" style="gap:6px;align-items:center" ${f ? `data-act="curio" data-arg="${c.id}"` : ''}>
    <span class="curio ${f ? '' : 'off'}">${icon(f ? c.icon : 'question', 24)}</span><span class="small" style="font-weight:650;color:${f ? 'var(--ink)' : 'var(--ink-soft)'}">${f ? esc(c.name) : '???'}</span></button>`; }).join('')}</div></div>`;

const journeyFeats = () => ACHIEVEMENTS.map((a) => {
  const d = S.achievements[a.id];
  return `<div class="list-row" style="opacity:${d ? 1 : 0.75}"><span style="width:46px;height:46px;border-radius:50%;display:grid;place-items:center;flex:none;background:${d ? '#F2C14E' : 'color-mix(in srgb,var(--line) 50%,transparent)'};color:${d ? 'var(--ink-fixed)' : 'var(--ink-soft)'}">${icon(a.icon, 22)}</span>
    <span class="spacer"><div class="label">${esc(a.title)}</div><div class="small soft">${esc(a.blurb)}</div></span>${d ? `<span class="tiny soft">${new Date(d).toLocaleDateString([], { month: 'short', day: 'numeric' })}</span>` : ''}</div>`;
}).join('');

// ---------------------------------------------------------------- Stats
function renderStats() {
  const c = G.counted(S), week = Math.floor(G.sessionsInWeek(S, Date.now()).reduce((a, r) => a + r.seconds, 0) / 60);
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(); d.setHours(12, 0, 0, 0); d.setDate(d.getDate() - i);
    const recs = G.sessionsOnDay(S, d.getTime());
    days.push({ d, cats: Object.keys(CATEGORIES).map((k) => [k, Math.floor(recs.filter((r) => r.category === k).reduce((a, r) => a + r.seconds, 0) / 60)]) });
  }
  const maxDay = Math.max(30, ...days.map((x) => x.cats.reduce((a, [, m]) => a + m, 0)));
  const bars = days.map((x, i) => {
    let y = 150;
    const bx = 14 + i * 44;
    const segs = x.cats.filter(([, m]) => m > 0).map(([k, m]) => { const h = (m / maxDay) * 130; y -= h; return `<rect x="${bx}" y="${y}" width="28" height="${h}" rx="4" fill="${CATEGORIES[k].color}"/>`; }).join('');
    return `${segs}<text x="${bx + 14}" y="170" text-anchor="middle" font-size="11" fill="currentColor" opacity=".6">${x.d.toLocaleDateString([], { weekday: 'narrow' })}</text>`;
  }).join('');
  const totals = Object.keys(CATEGORIES).map((k) => [k, Math.floor(c.filter((r) => r.category === k).reduce((a, r) => a + r.seconds, 0) / 60)]).filter(([, m]) => m > 0);
  const sum = totals.reduce((a, [, m]) => a + m, 0);
  let off = 0;
  const donut = totals.map(([k, m]) => { const len = (m / sum) * 301.6; const s = `<circle cx="60" cy="60" r="48" fill="none" stroke="${CATEGORIES[k].color}" stroke-width="18" stroke-dasharray="${Math.max(0, len - 2)} 302" stroke-dashoffset="${-off}"/>`; off += len; return s; }).join('');
  const byDay = {};
  for (const r of c) { const k = G.dayKey(r.start); byDay[k] = (byDay[k] || 0) + r.seconds / 60; }
  const nDays = Object.keys(byDay).length, longest = Math.max(0, ...c.map((r) => Math.floor(r.seconds / 60)));
  const best = Math.floor(Math.max(0, ...Object.values(byDay)));
  const tile = (title, value, ic) => `<div class="card" style="padding:14px"><span style="color:var(--amber)">${icon(ic, 18)}</span><div style="font-size:26px;font-weight:800">${value}</div><div class="small soft">${title}</div></div>`;
  const rec = (t, v, ic) => `<div class="row"><span style="color:var(--amber)">${icon(ic, 18)}</span><span class="spacer small">${t}</span><b class="small">${v}</b></div>`;
  return `<div class="screen" data-tab="stats"><div class="stack">
    <div class="title">Statistics</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">${tile('Today', fmtMin(G.todayMinutes(S)), 'sun')}${tile('This week', fmtMin(week), 'calendar')}
      ${tile('Lifetime', `${(G.totalMinutes(S) / 60).toFixed(1)}h`, 'flame')}${tile('Sessions', c.length, 'check')}</div>
    <div class="card stack" style="gap:8px"><div class="h2">Last 7 days</div>
      <svg viewBox="0 0 320 178" width="100%" role="img" aria-label="Minutes focused over the last seven days">${bars}</svg>
      <div class="chips small">${Object.entries(CATEGORIES).map(([, v]) => `<span class="row" style="gap:5px"><i style="width:9px;height:9px;border-radius:50%;background:${v.color}"></i>${v.title}</span>`).join('')}</div>
      <div class="small soft">Your daily goal is ${fmtMin(S.settings.dailyGoalMinutes)}. Any amount is progress.</div></div>
    ${totals.length ? `<div class="card stack" style="gap:10px"><div class="h2">Where your focus goes</div><div class="row" style="gap:18px">
      <svg width="120" height="120" style="transform:rotate(-90deg);flex:none">${donut}</svg>
      <div class="spacer stack" style="gap:8px">${totals.map(([k, m]) => `<div class="row small"><i style="width:10px;height:10px;border-radius:50%;background:${CATEGORIES[k].color}"></i><span class="spacer">${CATEGORIES[k].title}</span><span class="soft">${fmtMin(m)}</span></div>`).join('')}</div></div></div>` : ''}
    <div class="card stack" style="gap:12px"><div class="h2">Personal records</div>
      ${rec('Longest session', fmtMin(longest), 'clock')}${rec('Best day', fmtMin(best), 'star')}${rec('Days you focused', nDays, 'calendar')}
      ${rec('Average on focus days', fmtMin(nDays ? Math.floor(G.totalMinutes(S) / nDays) : 0), 'chart')}${rec('Places restored', `${Object.keys(S.restored).length}/${LANDMARKS.length}`, 'leaf')}</div>
    <div class="card stack" style="gap:12px"><div class="h2">Recent sessions</div>
      ${c.length ? c.slice(-15).reverse().map((r) => `<div class="row"><span class="orb-sm" style="background:${CATEGORIES[r.category].color};color:#fff">${icon(CATEGORIES[r.category].icon, 15)}</span>
        <div class="spacer"><div class="label">${CATEGORIES[r.category].title}</div><div class="tiny soft">${new Date(r.start).toLocaleString([], { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}</div></div>
        ${r.reachedTarget ? `<span style="color:var(--moss)">${icon('check', 16)}</span>` : ''}<b class="small">${fmtMin(Math.floor(r.seconds / 60))}</b></div>`).join('') : '<div class="small soft">Your sessions will appear here.</div>'}</div>
  </div></div>`;
}

// ---------------------------------------------------------------- Sheets
function sheetFrame(title, body, foot = '', cls = '') {
  return `<div class="sheet ${cls}" role="dialog" aria-label="${esc(title)}"><div class="grab"></div>
    <div class="sheet-head"><span class="h2">${title}</span><span class="spacer"></span><button data-act="closeSheet" aria-label="Close" class="soft" style="width:36px;height:36px;display:grid;place-items:center">${icon('close', 20)}</button></div>
    <div class="sheet-body">${body}</div>${foot ? `<div class="sheet-foot">${foot}</div>` : ''}</div>`;
}

function renderSheet() {
  const s = ui.sheet;
  if (s.type === 'setup') return sheetSetup();
  if (s.type === 'restore') return sheetRestore();
  if (s.type === 'path') return sheetPath();
  if (s.type === 'landmark') return sheetLandmark(byId(LANDMARKS, s.arg));
  if (s.type === 'decor') return sheetDecor();
  if (s.type === 'settings') return sheetSettings();
  if (s.type === 'chapter') return sheetChapter(byId(CHAPTERS, s.arg));
  return '';
}

function sheetSetup() {
  const u = ui.setup, presets = [15, 25, 45, 60];
  const body = `<div class="stack" style="gap:22px">
    <div class="row" style="gap:12px">${emberCv(G.appearance(S), 'curious', 84)}<div><div class="h2">What are we focusing on?</div><div class="small soft">${nm()} will keep the fire going.</div></div></div>
    <div class="stack" style="gap:10px"><div class="caps">Mode</div><div class="seg">
      <button class="${u.mode === 'countdown' ? 'on' : ''}" data-act="setup" data-arg="mode:countdown">Timer</button><button class="${u.mode === 'pomodoro' ? 'on' : ''}" data-act="setup" data-arg="mode:pomodoro">Pomodoro</button><button class="${u.mode === 'stopwatch' ? 'on' : ''}" data-act="setup" data-arg="mode:stopwatch">Stopwatch</button></div></div>
    ${u.mode === 'pomodoro' ? pomoSetup(u) : u.mode === 'countdown' ? `<div class="stack" style="gap:10px"><div class="caps">Length</div><div class="chips">
      ${presets.map((p) => `<button class="chip ${!u.custom && u.minutes === p ? 'on' : ''}" data-act="setup" data-arg="min:${p}">${p}m</button>`).join('')}
      <button class="chip ${u.custom ? 'on' : ''}" data-act="setup" data-arg="custom">Custom</button></div>
      ${u.custom ? `<div class="card row"><span class="label spacer">${u.minutes} minutes</span><div class="stepper"><button data-act="setup" data-arg="step:-5" aria-label="Less">−</button><button data-act="setup" data-arg="step:5" aria-label="More">+</button></div></div>` : ''}</div>`
      : '<p class="small soft">The stopwatch counts up until you finish. Every minute counts.</p>'}
    <div class="stack" style="gap:10px"><div class="caps">Category</div><div class="chips">${Object.entries(CATEGORIES).map(([k, c]) => `<button class="chip ${u.category === k ? 'on' : ''}" style="--chip:${c.color}" data-act="setup" data-arg="cat:${k}">${icon(c.icon, 16)}${c.title}</button>`).join('')}</div></div>
    <div class="stack" style="gap:10px"><div class="caps">Ambience</div><div class="chips">${Object.entries(AMBIENCE).map(([k, a]) => `<button class="chip ${u.ambient === k ? 'on' : ''}" data-act="setup" data-arg="amb:${k}">${icon(a.icon, 16)}${a.title}</button>`).join('')}</div></div>
  </div>`;
  const label = u.mode === 'countdown' ? `Focus for ${u.minutes} minutes` : u.mode === 'pomodoro' ? `Start round 1 of ${u.pomoEvery}` : 'Start stopwatch';
  return sheetFrame('Focus', body, `<button class="btn" data-act="startFocus">${icon('flame', 20)} ${label}</button>`);
}

const POMO_PRESETS = [['Classic', 25, 5, 15], ['Deep', 50, 10, 20], ['Gentle', 15, 3, 10]];
function pomoSetup(u) {
  const preset = POMO_PRESETS.find(([, f, sh, l]) => u.pomoFocus === f && u.pomoShort === sh && u.pomoLong === l);
  const stepRow = (key, label, val, d) => `<div class="form-row"><span class="spacer">${label}: <b>${val}</b></span><div class="stepper">
    <button data-act="setup" data-arg="pstep:${key}:${-d}" aria-label="Less">−</button><button data-act="setup" data-arg="pstep:${key}:${d}" aria-label="More">+</button></div></div>`;
  return `<div class="stack" style="gap:10px"><div class="caps">Rhythm</div><div class="chips">
    ${POMO_PRESETS.map(([n, f, sh, l]) => `<button class="chip ${preset && preset[0] === n ? 'on' : ''}" data-act="setup" data-arg="preset:${f},${sh},${l}">${n} ${f}/${sh}</button>`).join('')}
    <button class="chip ${preset ? '' : 'on'}" data-act="setup" data-arg="pcustom">Custom</button></div>
    ${preset && !u.pomoCustom ? '' : `<div class="card" style="padding:0 16px">${stepRow('pomoFocus', 'Focus', `${u.pomoFocus} min`, 5)}${stepRow('pomoShort', 'Short break', `${u.pomoShort} min`, 1)}
      ${stepRow('pomoLong', 'Long break', `${u.pomoLong} min`, 5)}${stepRow('pomoEvery', 'Rounds per cycle', u.pomoEvery, 1)}</div>`}
    <div class="row small soft" style="gap:6px;flex-wrap:wrap">${Array.from({ length: u.pomoEvery }, (_, i) => `<span class="pill" style="padding:4px 8px">${icon('flame', 12)} ${u.pomoFocus}m</span>${i < u.pomoEvery - 1 ? `<span>${u.pomoShort}m rest</span>` : ''}`).join('')}<span>then ${u.pomoLong}m long rest</span></div>
    <div class="row"><span class="spacer small">Start the next round or break automatically</span><button class="toggle ${u.pomoAuto ? 'on' : ''}" data-act="setup" data-arg="pauto" aria-pressed="${u.pomoAuto}" aria-label="Auto-start"></button></div>
    <p class="small soft">Work in focused rounds with short rests between them. Every round grows ${nm()}, and you can stop after any round.</p></div>`;
}

function sheetRestore() {
  const r = G.renewalsAvailable(S), avail = G.availableLandmarks(S);
  const body = `<div class="stack">
    <div><div class="h2" style="font-size:24px">What should come back to life?</div><div class="small soft">${plural(r, 'restoration')} available. Each place brings new life to the grove, and some bring new friends.</div></div>
    ${AREAS.filter((a) => G.isAreaUnlocked(S, a.id)).map((a) => {
      const opts = avail.filter((l) => l.area === a.id);
      if (!opts.length) return '';
      return `<div class="caps">${esc(a.name)}</div>${opts.map((l) => {
        const on = ui.restorePick === l.id;
        return `<div class="card" style="${on ? 'border:1.5px solid var(--amber)' : ''}"><button style="width:100%;text-align:left" class="row" data-act="pickLandmark" data-arg="${l.id}">
          <span class="spacer"><div class="h2" style="font-size:18px">${esc(l.name)}</div><div class="small soft">${esc(l.blurb)}</div>
          ${l.companion ? `<div class="small" style="color:var(--coral);font-weight:650;margin-top:4px">${icon('paw', 14)} Someone may move in</div>` : ''}</span>
          <span style="color:${on ? 'var(--amber)' : 'var(--line)'}">${icon(on ? 'check' : 'circle', 24)}</span></button>
          ${on ? `<div class="row" style="gap:10px;margin-top:12px;align-items:stretch">${l.variants.map((v) => `<button class="tile" style="flex:1;align-items:flex-start;text-align:left;${ui.restoreVariant === v.id ? 'border:2px solid var(--amber)' : ''}" data-act="pickVariant" data-arg="${v.id}">
            <span style="display:block;width:100%;height:34px;border-radius:10px;background:${v.color}"></span><span class="label">${esc(v.name)}</span><span class="tiny soft">${esc(v.blurb)}</span></button>`).join('')}</div>` : ''}</div>`;
      }).join('')}`;
    }).join('')}</div>`;
  const pick = ui.restorePick && byId(LANDMARKS, ui.restorePick);
  return sheetFrame('Restore', body, pick ? `<button class="btn" data-act="doRestore">${icon('leaf', 20)} Restore ${esc(pick.name)}</button>` : '');
}

function sheetPath() {
  const body = `<div class="stack">
    <div class="center"><div class="h2" style="font-size:24px">Who will ${nm()} become?</div><p class="small soft">This choice shapes ${nm()}'s look, abilities and future forms. It's permanent, so pick the one that feels like you.</p></div>
    ${Object.entries(PATHS).map(([id, p]) => {
      const on = ui.pathPick === id, tint = COSMETICS.find((c) => c.unlock.path === id).id;
      const look = { ...G.appearance(S), stage: 2, path: id, flameTint: tint };
      return `<button class="card row" style="align-items:flex-start;gap:12px;text-align:left;${on ? 'border:2.5px solid var(--amber)' : ''}" data-act="pickPath" data-arg="${id}">
        <div class="center">${emberCv(look, on ? 'happy' : 'idle', 104, on)}<div class="row tiny soft" style="justify-content:center;gap:2px">Later: ${emberCv({ ...look, stage: 4 }, 'idle', 36, false)}</div></div>
        <div class="stack" style="gap:6px"><div class="h2" style="font-size:22px">${p.title}</div><div class="small soft">${p.tagline}</div>
        ${ABILITIES.filter((a) => a.path === id).map((a) => `<div class="tiny">• <b>${a.name}</b>: ${a.blurb}</div>`).join('')}</div></button>`;
    }).join('')}</div>`;
  return sheetFrame('Evolution', body, `<button class="btn" data-act="doPath">Become a ${esc(stageFor(2, ui.pathPick).name)}</button>`);
}

function sheetLandmark(l) {
  const v = l.variants.find((x) => x.id === S.restored[l.id]), canRestore = G.availableLandmarks(S).includes(l);
  const c = l.companion && byId(COMPANIONS, l.companion);
  const body = `<div class="stack" style="gap:14px">
    <div class="caps">${esc(byId(AREAS, l.area).name)}</div>
    ${v ? `<div class="row"><i style="width:14px;height:14px;border-radius:50%;background:${v.color}"></i><b>${esc(v.name)}</b></div><p class="serif" style="font-size:19px">${esc(l.restoredText)}</p>`
      : `<p class="serif" style="font-size:19px">${esc(l.blurb)}</p>${canRestore ? `<p class="small soft">${G.renewalsAvailable(S) > 0 ? 'You can restore this now.' : 'Keep focusing to earn your next restoration.'}</p>
        ${G.renewalsAvailable(S) > 0 ? `<button class="btn" data-act="openSheet" data-arg="restore">${icon('leaf', 20)} Restore</button>` : ''}` : ''}`}
    ${c ? `<div class="card row" style="gap:12px;${v ? '' : 'filter:grayscale(1);opacity:.6'}">${companionCv(c.id, 56)}<div><div class="label">${v ? esc(c.name) : 'Someone might live here…'}</div>
      ${v ? `<div class="small soft">${esc(c.species)}</div>${heartsRow(G.hearts(S, c.id), 10)}` : ''}</div></div>` : ''}</div>`;
  return sheetFrame(esc(l.name), body);
}

function sheetDecor() {
  const body = `<div class="stack" style="gap:10px">${DECORATIONS.map((d) => {
    const own = S.ownedDecorations.includes(d.id), shown = !S.hiddenDecorations.includes(d.id);
    return `<div class="list-row"><span class="spacer"><div class="label">${esc(d.name)}</div><div class="small soft">${esc(d.blurb)}</div></span>
      ${own ? `<button class="toggle ${shown ? 'on' : ''}" data-act="toggleDecor" data-arg="${d.id}" aria-label="Show ${esc(d.name)}" aria-pressed="${shown}"></button>`
        : `<button class="btn small-btn ${S.seeds >= d.cost ? '' : 'secondary'}" data-act="buyDecor" data-arg="${d.id}"><span class="seed"></span>${d.cost}</button>`}</div>`;
  }).join('')}<p class="small soft">Decorations appear around the hearth. Earn Seeds by focusing and finishing quests.</p></div>`;
  return sheetFrame(`Decorate <span class="pill" style="margin-left:8px;color:var(--seeds)"><span class="seed"></span>${S.seeds}</span>`, body);
}

function sheetSettings() {
  const s = S.settings;
  const tog = (key, label) => `<div class="form-row"><span class="spacer">${label}</span><button class="toggle ${s[key] ? 'on' : ''}" data-act="toggleSetting" data-arg="${key}" aria-pressed="${!!s[key]}" aria-label="${label}"></button></div>`;
  const step = (key, label, val, d) => `<div class="form-row"><span class="spacer">${label}: <b>${val}</b></span><div class="stepper"><button data-act="stepSetting" data-arg="${key}:${-d}">−</button><button data-act="stepSetting" data-arg="${key}:${d}">+</button></div></div>`;
  const sel = (key, label, opts) => `<div class="form-row"><span class="spacer">${label}</span><select data-set="${key}">${opts.map(([v, l]) => `<option value="${v}" ${s[key] === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>`;
  const body = `<div class="stack">
    <div class="caps">Focus timer</div><div class="card" style="padding:0 16px">
      ${sel('defaultMode', 'Default mode', [['countdown', 'Timer'], ['pomodoro', 'Pomodoro'], ['stopwatch', 'Stopwatch']])}
      ${step('defaultMinutes', 'Default length', `${s.defaultMinutes} min`, 5)}
      ${sel('defaultCategory', 'Default category', Object.entries(CATEGORIES).map(([k, c]) => [k, c.title]))}
      ${step('dailyGoalMinutes', 'Daily goal', fmtMin(s.dailyGoalMinutes), 15)}
      ${tog('keepScreenAwake', 'Keep screen awake while focusing')}</div>
    <div class="caps">Pomodoro</div><div class="card" style="padding:0 16px">
      ${step('pomoFocus', 'Focus round', `${s.pomoFocus} min`, 5)}${step('pomoShort', 'Short break', `${s.pomoShort} min`, 1)}
      ${step('pomoLong', 'Long break', `${s.pomoLong} min`, 5)}${step('pomoEvery', 'Rounds per cycle', s.pomoEvery, 1)}
      ${tog('pomoAuto', 'Start next round or break automatically')}</div>
    <div class="caps">Sound</div><div class="card" style="padding:0 16px">
      ${sel('ambient', 'Ambience', Object.entries(AMBIENCE).map(([k, a]) => [k, a.title]))}
      <div class="form-row"><span>Volume</span><input type="range" min="0" max="1" step="0.05" value="${s.ambientVolume}" data-set="ambientVolume" aria-label="Ambience volume"></div>
      ${tog('soundEffects', 'Sound effects')}</div>
    <div class="caps">Accessibility & display</div><div class="card" style="padding:0 16px">
      ${tog('reduceMotion', 'Reduce motion')}
      ${sel('appearance', 'Appearance', [['system', 'System'], ['light', 'Light'], ['dark', 'Dark']])}</div>
    <div class="caps">Your progress</div><div class="card" style="padding:0 16px">
      <div class="form-row"><span class="spacer small soft">Progress is saved on this device. Make a backup now and then, and before clearing Safari's data.</span></div>
      <div class="form-row"><button class="label" style="color:var(--amber)" data-act="exportData">Copy a backup</button><span class="spacer"></span><button class="label" style="color:var(--amber)" data-act="importData">Restore a backup</button></div>
      <div class="form-row"><button class="label" style="color:var(--coral)" data-act="reset">Start a new grove</button></div></div>
    <p class="tiny soft center">Ember Grove · original art drawn in code, sound synthesized live.</p></div>`;
  return sheetFrame('Settings', body);
}

function sheetChapter(c) {
  const p = Math.min(ui.chapterPage, c.pages.length - 1), last = p === c.pages.length - 1;
  const body = `<div class="stack center" style="gap:18px;align-items:center;color:var(--cream)">
    <div class="caps" style="color:var(--lavender)">Chapter ${c.number}</div>
    <div class="serif" style="font-size:30px;font-weight:700">${esc(c.title)}</div>
    ${emberCv(G.appearance(S), last ? 'happy' : 'curious', 120)}
    <p class="serif" style="font-size:20px;line-height:1.5;min-height:150px" aria-live="polite">${esc(c.pages[p].replaceAll('{name}', S.emberName))}</p>
    <div class="row" style="gap:6px">${c.pages.map((_, i) => `<i style="width:7px;height:7px;border-radius:50%;background:${i === p ? 'var(--cream)' : 'rgba(255,255,255,.3)'}"></i>`).join('')}</div></div>`;
  return sheetFrame('', body, `<button class="btn" data-act="chapterNext">${last ? 'Close' : 'Next'}</button>`, 'chapter').replace('class="sheet chapter"', 'class="sheet chapter" style="background:linear-gradient(var(--dusk-deep),var(--dusk))"');
}

function renderDialog() {
  const d = ui.dialog;
  return `<div class="dialog-bd" data-act="${d.cancel || 'closeDialog'}"></div><div class="dialog" role="alertdialog"><div class="stack" style="gap:10px">
    <div class="h2">${esc(d.title)}</div>${d.body ? `<p class="small soft">${esc(d.body)}</p>` : ''}${d.input ? `<input type="text" id="dlgInput" value="${esc(d.input)}" maxlength="16" autocomplete="off">` : ''}
    <div class="stack" style="gap:8px;margin-top:6px">${d.buttons.map((b) => `<button class="btn ${b.secondary ? 'secondary' : ''}" style="${b.danger ? 'color:var(--coral)' : ''}" data-act="${b.act}" data-arg="${b.arg || ''}">${esc(b.label)}</button>`).join('')}</div></div></div>`;
}

// ---------------------------------------------------------------- Focus overlay
const LINES = ['{name} is tending the fire.', 'The grove is quiet. Just you and the work.', '{name} added another twig to the fire.', 'Somewhere in the grove, a firefly woke up.',
  'The frost is thinning, just a little.', '{name} is humming very softly.', 'The stars are out. The fire is warm.'];

function renderFocus() {
  const a = S.activeSession, cat = CATEGORIES[a.category], amb = AMBIENCE[S.settings.ambient];
  return `<div class="overlay" style="color-scheme:dark">
    <canvas class="bgscene" data-kind="grove" data-live="focus" data-vp="auto" data-es="130"></canvas>
    <div class="dim-top"></div>
    <div class="focus-ui">
      <div class="row"><span class="ghost-pill">${icon(cat.icon, 16)} ${cat.title}</span><span class="spacer"></span>
        <button class="ghost-pill" data-act="cycleAmbient" aria-label="Ambient sound: ${amb.title}">${icon(amb.icon, 18)} ${amb.title}</button></div>
      <div style="height:6vh"></div>
      <div id="timer" class="timer" role="timer">--:--</div>
      ${a.target ? `<div style="width:220px;margin:12px auto 0"><div class="bar thin"><i id="fbar" style="width:0%;transition:none"></i></div></div>` : ''}
      <p id="fline" class="center" style="color:var(--lavender);margin-top:12px;font-size:16px"></p>
      ${a.pomo && S.pomo ? roundDots(S.pomo.cycle, S.settings.pomoEvery, true) : ''}
      <div class="spacer"></div>
      <div class="row" style="justify-content:center;gap:28px">
        <button class="round-btn" data-act="${a.pausedAt ? 'resume' : 'pause'}" aria-label="${a.pausedAt ? 'Resume' : 'Pause'}">${icon(a.pausedAt ? 'play' : 'pause', 30)}</button>
        <button class="round-btn ghost" data-act="finish" aria-label="Finish session">${icon('check', 26)}</button>
      </div>
    </div></div>`;
}

let lastTimerText = '';
function updateFocusText() {
  const a = S.activeSession || S.activeBreak, el = document.getElementById('timer');
  if (!a || !el) return;
  if (!S.activeSession) {
    const txt = fmtDur(Math.ceil(G.remaining(a)));
    if (txt !== lastTimerText) {
      el.textContent = txt; lastTimerText = txt;
      const fb = document.getElementById('fbar');
      if (fb) fb.style.width = `${Math.min(100, G.progress(a) * 100)}%`;
      document.title = `${txt} · Break · Ember Grove`;
    }
    return;
  }
  const now = Date.now(), e = G.elapsed(a, now), shown = a.target ? G.remaining(a, now) : e;
  const txt = fmtDur(a.target ? Math.ceil(shown) : shown);
  if (txt !== lastTimerText) {
    el.textContent = txt; lastTimerText = txt;
    const fb = document.getElementById('fbar');
    if (fb) fb.style.width = `${Math.min(100, G.progress(a, now) * 100)}%`;
    const fl = document.getElementById('fline');
    if (fl) fl.textContent = a.pausedAt ? `${S.emberName} is dozing while you rest.` : LINES[Math.floor(e / 240) % LINES.length].replaceAll('{name}', S.emberName);
    document.title = a.pausedAt ? 'Paused · Ember Grove' : `${txt} · Ember Grove`;
  }
}

// ---------------------------------------------------------------- Reward overlay
function beats(r) {
  const b = ['glow'];
  if (r.levelAfter > r.levelBefore) b.push('level');
  if (r.evolved) b.push('evolution');
  b.push('seeds');
  if (r.companionVisit) b.push('companion');
  if (r.discovery) b.push('discovery');
  if (r.renewalsEarned > 0) b.push('renewal');
  r.milestones.areas.forEach((x) => b.push(`area:${x}`));
  r.milestones.chapters.forEach((x) => b.push(`chapter:${x}`));
  r.newCosmetics.forEach((x) => b.push(`cosmetic:${x}`));
  r.milestones.achievements.forEach((x) => b.push(`achievement:${x}`));
  if (r.questsReady > 0) b.push('quests');
  return b;
}

const rcard = (ic, color, inner) => `<div class="rcard"><span class="orb" style="background:${color};box-shadow:0 0 12px ${color}">${icon(ic, 22)}</span><div class="spacer">${inner}</div></div>`;
const giftText = (g) => (g.seeds ? `${g.seeds} Seeds` : g.cosmetic ? byId(COSMETICS, g.cosmetic).name : byId(DECORATIONS, g.decoration).name);

function beatCard(b, r) {
  const [kind, id] = b.split(':');
  switch (kind) {
    case 'glow': return rcard('flame', '#F5A524', `<div class="row"><b style="font-size:24px" id="glowCount">+${ui.revealed > 1 ? r.glowTotal : 0} Glow</b><span class="spacer"></span><span class="badge-level">Lv ${r.levelAfter}</span></div>
      ${r.glowLines.map((l) => `<div class="row small lav"><span class="spacer">${esc(l.label)}</span>+${l.amount}</div>`).join('')}
      <div style="margin-top:8px">${bar(ui.revealed > 1 ? G.levelProgress(S.xp) : 0)}</div>`);
    case 'level': return rcard('arrowUp', '#FFD27A', `<b style="font-size:22px">Level ${r.levelAfter}!</b><div class="small lav">${nm()} feels stronger and a little taller.</div>`);
    case 'evolution': {
      const st = stageFor(r.appearanceAfter.stage, r.appearanceAfter.path);
      return rcard('sparkles', '#FFE07A', `<div class="row" style="justify-content:center;gap:6px">${emberCv(r.appearanceBefore, 'idle', 80, false, 'opacity:.6')}<span class="lav">${icon('chevron', 20)}</span>${emberCv(r.appearanceAfter, 'happy', 110)}</div>
        <div class="center"><b style="font-size:20px">${nm()} evolved into a ${esc(st.name)}!</b><div class="small lav">${esc(st.blurb)}</div></div>`);
    }
    case 'seeds': return rcard('leaf', '#8FCB6A', `<div class="row"><span class="seed" style="width:16px;height:20px"></span><b style="font-size:20px">+${r.seeds} Seeds</b><span class="spacer"></span><span class="small lav">${S.seeds} total</span></div>`);
    case 'companion': {
      const v = r.companionVisit, c = byId(COMPANIONS, v.companion);
      return rcard('heart', '#E8674A', `<div class="row" style="align-items:flex-start;gap:12px"><div style="width:64px;height:64px;border-radius:50%;background:rgba(255,255,255,.08);flex:none">${companionCv(c.id, 64)}</div>
        <div class="stack" style="gap:6px"><b style="font-size:18px">${esc(c.name)} kept you company</b>${heartsRow(v.heartsAfter, 11)}
        ${v.memories.map((m) => `<div class="small serif" style="font-style:italic">${esc(m)}</div>`).join('')}
        ${v.gifts.map((g) => `<div class="small" style="color:var(--amber-glow);font-weight:700">Gift: ${esc(giftText(g))}</div>`).join('')}</div></div>`);
    }
    case 'discovery': {
      const c = byId(CURIOS, r.discovery);
      return rcard('search', '#7FC8FF', `<div class="row" style="gap:14px"><span class="curio" style="width:56px;height:56px;flex:none">${icon(c.icon, 24)}</span>
        <div><div class="tiny" style="color:var(--amber-glow);font-weight:700">Discovery!</div><b style="font-size:18px">${esc(c.name)}</b><div class="small lav">${esc(c.blurb)}</div></div></div>`);
    }
    case 'renewal': return rcard('leaf', '#8FCB6A', '<b style="font-size:20px">The grove stirs</b><div class="small lav">You earned a restoration. Choose what comes back to life.</div>');
    case 'area': { const a = byId(AREAS, id); return rcard('map', '#B79CFF', `<b style="font-size:20px">New area: ${esc(a.name)}</b><div class="small lav">${esc(a.blurb)}</div>`); }
    case 'chapter': { const c = byId(CHAPTERS, id); return rcard('book', '#FFD27A', `<b style="font-size:18px">Chapter ${c.number}: ${esc(c.title)}</b><div class="small lav">A new page of the story is waiting in Journey.</div>`); }
    case 'cosmetic': {
      const c = byId(COSMETICS, id), worn = G.equipped(S, c.slot) === c.id;
      return rcard('gift', '#E8674A', `<div class="row"><div class="spacer"><b style="font-size:18px">Unlocked: ${esc(c.name)}</b><div class="small lav">${esc(c.blurb)}</div></div>
        <button class="btn small-btn" data-act="rewardWear" data-arg="${c.id}">${worn ? 'Wearing' : 'Wear it'}</button></div>`);
    }
    case 'achievement': { const a = byId(ACHIEVEMENTS, id); return rcard(a.icon, '#F2C14E', `<b style="font-size:18px">${esc(a.title)}</b><div class="small lav">${esc(a.blurb)}</div>`); }
    case 'quests': return rcard('gift', '#F5A524', `<b style="font-size:17px">${plural(r.questsReady, 'quest reward')} ready to claim</b>`);
  }
  return '';
}

function renderReward() {
  const r = ui.reward, bs = beats(r), done = ui.revealed >= bs.length;
  const evoIdx = bs.indexOf('evolution'), evolved = evoIdx >= 0 && ui.revealed > evoIdx;
  const path = G.canChoosePath(S), restore = G.renewalsAvailable(S) > 0 && G.availableLandmarks(S).length > 0;
  return `<div class="overlay reward" data-act="rewardTap" style="color-scheme:dark">
    <div class="stack" style="padding:calc(var(--safe-top) + 20px) var(--gutter) 200px;gap:14px">
      <div class="stack center" style="align-items:center;gap:6px">${emberCv(evolved ? r.appearanceAfter : r.appearanceBefore, 'celebrating', 170)}
        <div style="font-size:30px;font-weight:800">Session complete</div><div class="lav" style="font-weight:600">${fmtMin(Math.floor(r.record.seconds / 60))} of ${CATEGORIES[r.record.category].title.toLowerCase()}</div></div>
      ${bs.slice(0, ui.revealed).map((b, i) => beatCard(b, r).replace('class="rcard"', `class="rcard${i === ui.revealed - 1 ? ' new' : ''}"`)).join('')}
    </div>
    <div style="position:fixed;left:0;right:0;bottom:0;padding:20px var(--gutter) calc(var(--safe-bottom) + 14px);background:linear-gradient(transparent, rgba(30,22,48,.96) 40%)" class="stack">
      ${done && r.pomo ? pomoRewardButtons(r, path, restore) : done ? `${path ? `<button class="btn" data-act="rewardGo" data-arg="path">${icon('sparkles', 20)} Choose ${nm()}'s path</button>` : restore ? `<button class="btn" data-act="rewardGo" data-arg="restore">${icon('leaf', 20)} Restore the grove</button>` : ''}
        <button class="btn ${path || restore ? 'secondary' : ''}" data-act="rewardGo" data-arg="">Back to the hearth</button>`
      : '<div class="center tiny" style="color:var(--lavender)">Tap to continue</div>'}
    </div></div>`;
}

function revealNext() {
  const r = ui.reward;
  if (!r) return;
  const bs = beats(r);
  if (ui.revealed >= bs.length) return;
  const b = bs[ui.revealed++];
  renderLayer();
  const ov = $layer.querySelector('.reward');
  if (ov) ov.scrollTop = ov.scrollHeight;
  const kind = b.split(':')[0];
  if (kind === 'glow') {
    ui.glowStart = performance.now();
    setTimeout(() => { const i = $layer.querySelector('.rcard .bar i'); if (i) i.style.width = `${G.levelProgress(S.xp) * 100}%`; }, 60);
  } else if (kind === 'level' || kind === 'evolution') {
    sfx('levelUp');
    if (kind === 'evolution' && !reduceMotion()) { const f = document.createElement('div'); f.className = 'flash'; document.body.appendChild(f); setTimeout(() => f.remove(), 1200); }
  } else if (['discovery', 'cosmetic', 'chapter', 'area'].includes(kind)) sfx('discover');
}

function scheduleReveal(delay = 1100) {
  clearTimeout(ui.revealTimer);
  if (!ui.reward || ui.revealed >= beats(ui.reward).length) return;
  ui.revealTimer = setTimeout(() => { revealNext(); scheduleReveal(); }, delay);
}

// ---------------------------------------------------------------- Onboarding
function renderOnboarding() {
  const step = ui.onboardStep, mood = ['sleepy', 'curious', 'happy'][step];
  const page = (t, b) => `<div class="serif" style="font-size:28px;font-weight:700">${t}</div><p class="serif" style="color:var(--lavender);font-size:18px;line-height:1.5">${b}</p>`;
  return `<div class="overlay" style="background:linear-gradient(var(--dusk-deep),var(--dusk),#4A3768);color-scheme:dark">
    <div class="focus-ui" style="align-items:center;text-align:center;gap:20px">
      <div class="spacer"></div>
      <div style="width:300px;height:300px;border-radius:50%;display:grid;place-items:center;background:radial-gradient(circle, rgba(255,210,122,${step ? 0.45 : 0.15}), transparent 65%);transition:background 1s">
        ${emberCv({ stage: 0, path: null, head: null, neck: null, face: null, flameTint: 'amber' }, mood, step ? 190 : 150)}</div>
      <div class="stack" style="gap:12px;max-width:360px;animation:rise .5s">
        ${step === 0 ? page('The grove has gone cold', 'The fire went out long ago, and the creatures drifted away. But in the ashes, something is still glowing.')
        : step === 1 ? page("It's waiting for you", 'When you focus in the real world, it keeps the fire alive. Every minute helps it grow, and brings the grove back to life.')
        : `<div style="font-size:26px;font-weight:800">What will you call it?</div><input type="text" id="nameInput" value="${nm()}" maxlength="16" autocomplete="off" style="text-align:center;background:rgba(255,255,255,.1);border-color:rgba(255,255,255,.2);color:var(--cream)">
          <p class="small" style="color:var(--lavender)">No streaks to break. No penalties for rest. Just you, your work, and a little friend who's glad you're here.</p>`}
      </div>
      <div class="spacer"></div>
      <button class="btn" data-act="onboard">${['Look closer', 'Wake it gently', 'Light the first spark'][step]}</button>
    </div></div>`;
}

// ---------------------------------------------------------------- Session control
let wakeLock = null;
async function keepAwake(on) {
  try {
    if (on && S.settings.keepScreenAwake && 'wakeLock' in navigator && document.visibilityState === 'visible') wakeLock = await navigator.wakeLock.request('screen');
    else if (!on && wakeLock) { await wakeLock.release(); wakeLock = null; }
  } catch (e) { /* not supported */ }
}

function startSession() {
  const u = ui.setup;
  Sound.unlock();
  commit((s) => {
    s.settings.defaultMode = u.mode; s.settings.defaultCategory = u.category; s.settings.ambient = u.ambient;
    if (u.mode === 'countdown') s.settings.defaultMinutes = u.minutes;
    if (u.mode === 'pomodoro') {
      Object.assign(s.settings, { pomoFocus: u.pomoFocus, pomoShort: u.pomoShort, pomoLong: u.pomoLong, pomoEvery: u.pomoEvery, pomoAuto: u.pomoAuto });
      s.pomo = { cycle: 1, category: u.category };
      s.activeBreak = null;
      s.activeSession = { mode: 'countdown', pomo: true, category: u.category, startDate: Date.now(), target: u.pomoFocus * 60, pausedTotal: 0, pausedAt: null };
      return;
    }
    s.pomo = null;
    s.activeSession = { mode: u.mode, category: u.category, startDate: Date.now(), target: u.mode === 'countdown' ? u.minutes * 60 : null, pausedTotal: 0, pausedAt: null };
  });
  ui.sheet = null; lastTimerText = '';
  render();
  Sound.setAmbient(S.settings.ambient, S.settings.ambientVolume);
  sfx('start');
  keepAwake(true);
}

function finishSession(at = Date.now()) {
  const a = S.activeSession;
  if (!a) return;
  const seconds = Math.floor(G.elapsed(a, at));
  const record = { start: a.startDate, end: at, seconds, category: a.category, mode: a.mode, reachedTarget: G.isComplete(a, at) };
  Sound.stopAmbient(); keepAwake(false); document.title = 'Ember Grove';
  ui.dialog = null;
  if (seconds < 60) { commit((s) => { s.activeSession = null; s.pomo = null; }); return; }
  let summary, pomo = null;
  commit((s) => {
    s.activeSession = null;
    if (a.pomo && s.pomo) {
      const every = s.settings.pomoEvery, long = s.pomo.cycle % every === 0;
      if (long) s.pomoSets = (s.pomoSets || 0) + 1;
      pomo = { cycle: s.pomo.cycle, every, nextBreak: long ? 'long' : 'short' };
    }
    summary = G.applySession(s, record, at);
  });
  summary.pomo = pomo;
  ui.reward = summary; ui.revealed = 0;
  renderLayer();
  sfx('complete');
  scheduleReveal(800);
}

function checkCompletion() {
  const b = S.activeBreak;
  if (b && !b.done && Date.now() >= G.endDate(b)) {
    commit((s) => { s.activeBreak.done = true; });
    sfx('discover');
    if (S.settings.pomoAuto) startNextRound();
  }
  const a = S.activeSession;
  if (!a || a.mode !== 'countdown' || a.pausedAt) return;
  const end = G.endDate(a);
  if (end && Date.now() >= end) finishSession(end);
}

// ---------------------------------------------------------------- Pomodoro
const REST_TIPS = ['Stand up and stretch your arms and back.', 'Drink a glass of water.', 'Look at something far away for 20 seconds.',
  'Take three slow, deep breaths.', 'Step outside or open a window for a moment.', 'Close your eyes and let them rest.', 'Walk around the room once or twice.'];

function clampPomo(key, v) {
  const lim = { pomoFocus: [5, 90], pomoShort: [1, 30], pomoLong: [5, 60], pomoEvery: [2, 8] }[key];
  return Math.min(lim[1], Math.max(lim[0], v));
}

function roundDots(cycle, every, dark) {
  return `<div class="row" style="justify-content:center;gap:8px;margin-top:14px" aria-label="Round ${cycle} of ${every}">
    ${Array.from({ length: every }, (_, i) => `<span style="width:10px;height:10px;border-radius:50%;background:${i < cycle ? 'var(--amber)' : dark ? 'rgba(255,255,255,.25)' : 'var(--line)'};${i === cycle - 1 ? 'box-shadow:0 0 8px var(--amber)' : ''}"></span>`).join('')}
    <span class="small" style="color:var(--lavender);margin-left:4px">Round ${cycle} of ${every}</span></div>`;
}

function pomoRewardButtons(r, path, restore) {
  const p = r.pomo, mins = p.nextBreak === 'long' ? S.settings.pomoLong : S.settings.pomoShort;
  return `${p.nextBreak === 'long' ? `<div class="center small" style="color:var(--amber-glow);font-weight:700">Full cycle complete: ${p.every} rounds!</div>` : ''}
    <button class="btn" data-act="startBreak">${icon('leaf', 20)} Take a ${mins}-minute ${p.nextBreak === 'long' ? 'long ' : ''}break</button>
    ${path ? `<button class="btn secondary" data-act="rewardGo" data-arg="path">${icon('sparkles', 20)} Choose ${nm()}'s path</button>`
      : restore ? `<button class="btn secondary" data-act="rewardGo" data-arg="restore">${icon('leaf', 20)} Restore the grove</button>` : ''}
    <div class="row" style="gap:10px"><button class="btn secondary" style="font-size:16px;padding:13px 10px" data-act="skipBreak">Skip break</button><button class="btn secondary" style="font-size:16px;padding:13px 10px" data-act="endPomo">Finish for now</button></div>`;
}

function startBreak() {
  const p = ui.reward && ui.reward.pomo;
  if (!p) return;
  clearTimeout(ui.revealTimer); ui.reward = null;
  const kind = p.nextBreak, mins = kind === 'long' ? S.settings.pomoLong : S.settings.pomoShort;
  commit((s) => { s.activeBreak = { kind, startDate: Date.now(), target: mins * 60, pausedTotal: 0, pausedAt: null, tip: Math.floor(Math.random() * REST_TIPS.length) }; });
  lastTimerText = '';
  keepAwake(true);
}

function startNextRound() {
  if (!S.pomo) return;
  Sound.unlock();
  clearTimeout(ui.revealTimer); ui.reward = null;
  commit((s) => {
    const wasLong = s.activeBreak?.kind === 'long' || s.pomo.cycle % s.settings.pomoEvery === 0;
    s.pomo.cycle = wasLong ? 1 : s.pomo.cycle + 1;
    s.activeBreak = null;
    s.activeSession = { mode: 'countdown', pomo: true, category: s.pomo.category, startDate: Date.now(), target: s.settings.pomoFocus * 60, pausedTotal: 0, pausedAt: null };
  });
  lastTimerText = '';
  Sound.setAmbient(S.settings.ambient, S.settings.ambientVolume);
  sfx('start');
  keepAwake(true);
}

function renderBreak() {
  const b = S.activeBreak, long = b.kind === 'long', every = S.settings.pomoEvery;
  const cycle = S.pomo ? S.pomo.cycle : 1, nextRound = long ? 1 : cycle + 1;
  return `<div class="overlay" style="color-scheme:dark">
    <canvas class="bgscene" data-kind="grove" data-live="break" data-vp="auto" data-es="130"></canvas>
    <div class="dim-top"></div>
    <div class="focus-ui">
      <div class="row"><span class="ghost-pill">${icon('leaf', 16)} ${long ? 'Long break' : 'Short break'}</span><span class="spacer"></span>
        <span class="ghost-pill">${icon('clock', 16)} Pomodoro</span></div>
      <div style="height:6vh"></div>
      ${b.done ? `<div class="center" style="font-size:40px;font-weight:800">Break's over</div>
        <p class="center" style="color:var(--lavender);margin-top:10px;font-size:17px">${nm()} is stretching. Ready for round ${nextRound}?</p>`
      : `<div id="timer" class="timer" role="timer">--:--</div>
        <div style="width:220px;margin:12px auto 0"><div class="bar thin" style="--c:#8FCB6A"><i id="fbar" style="width:0%;transition:none"></i></div></div>
        <p class="center" style="color:var(--lavender);margin-top:14px;font-size:16px">${long ? `A whole cycle done. ${nm()} is napping in the sun.` : `${nm()} is resting by the fire.`}</p>
        <div class="center" style="margin-top:18px"><span class="ghost-pill">${icon('sparkles', 16)} ${REST_TIPS[b.tip || 0]}</span></div>`}
      ${roundDots(long ? every : cycle, every, true)}
      <div class="spacer"></div>
      <div class="stack" style="gap:10px">
        ${b.done ? `<button class="btn" data-act="nextRound">${icon('flame', 20)} Start round ${nextRound}</button>` : `<button class="btn" data-act="nextRound">${icon('flame', 20)} Skip break, start round ${nextRound}</button>`}
        <button class="btn secondary" style="background:rgba(255,255,255,.12);color:var(--cream);border-color:rgba(255,255,255,.2)" data-act="endPomo">Finish for now</button>
      </div>
    </div></div>`;
}

// ---------------------------------------------------------------- Banner
function showBanner(ch) {
  if (!ch) return;
  let b = null;
  if (ch.chapters.length) b = { icon: 'book', title: `New chapter: ${byId(CHAPTERS, ch.chapters[0]).title}`, sub: 'Read it in Journey → Story' };
  else if (ch.companionsArrived.length) { const c = byId(COMPANIONS, ch.companionsArrived[0]); b = { icon: 'paw', title: `${c.name} arrived`, sub: c.blurb }; }
  else if (ch.areas.length) { const a = byId(AREAS, ch.areas[0]); b = { icon: 'map', title: `${a.name} is open`, sub: a.blurb }; }
  else if (ch.achievements.length) { const a = byId(ACHIEVEMENTS, ch.achievements[0]); b = { icon: a.icon, title: `Achievement: ${a.title}`, sub: a.blurb }; }
  if (!b) return;
  ui.banner = b; renderLayer();
  clearTimeout(showBanner.t);
  showBanner.t = setTimeout(() => { ui.banner = null; renderLayer(); }, 4200);
}

// ---------------------------------------------------------------- Actions
function openSheet(type, arg) {
  if (type === 'setup' && (S.activeSession || S.activeBreak)) { render(); return; }
  if (type === 'setup') {
    const s = S.settings;
    ui.setup = { mode: s.defaultMode, minutes: s.defaultMinutes, category: s.defaultCategory, ambient: s.ambient, custom: ![15, 25, 45, 60].includes(s.defaultMinutes),
      pomoFocus: s.pomoFocus, pomoShort: s.pomoShort, pomoLong: s.pomoLong, pomoEvery: s.pomoEvery, pomoAuto: s.pomoAuto, pomoCustom: false };
  }
  if (type === 'restore') { ui.restorePick = null; ui.restoreVariant = null; }
  if (type === 'path') ui.pathPick = 'hearth';
  if (type === 'chapter') ui.chapterPage = 0;
  ui.scroll.sheet = 0;
  $layer.querySelector('.sheet-body')?.remove();
  ui.sheet = { type, arg };
  renderLayer();
}

let pokeTimer;
const actions = {
  tab: (id) => { ui.tab = id; ui.speech = null; render(); },
  openSheet: (arg) => openSheet(arg),
  closeSheet: () => { ui.sheet = null; renderLayer(); },
  closeDialog: () => { ui.dialog = null; renderLayer(); },
  dismissBanner: () => { ui.banner = null; renderLayer(); },
  hideInstallTip: () => commit((s) => { s.settings.hideInstallTip = true; }),
  pokeEmber: () => {
    Sound.unlock(); sfx('tap');
    ui.mood = ['happy', 'celebrating', 'curious'][Math.floor(Math.random() * 3)];
    if (ui.tab === 'home') { ui.mood = 'happy'; ui.speech = chatter(); }
    render();
    clearTimeout(pokeTimer);
    pokeTimer = setTimeout(() => { ui.mood = 'idle'; ui.speech = null; render(); }, 3200);
  },
  setup: (arg) => {
    const [k, v] = arg.split(':'), u = ui.setup;
    if (k === 'mode') u.mode = v;
    if (k === 'preset') { [u.pomoFocus, u.pomoShort, u.pomoLong] = v.split(',').map(Number); u.pomoCustom = false; }
    if (k === 'pcustom') u.pomoCustom = true;
    if (k === 'pauto') u.pomoAuto = !u.pomoAuto;
    if (k === 'pstep') { const [key, d] = arg.split(':').slice(1); u[key] = clampPomo(key, u[key] + +d); u.pomoCustom = true; }
    if (k === 'min') { u.minutes = +v; u.custom = false; }
    if (k === 'custom') u.custom = true;
    if (k === 'step') u.minutes = Math.min(180, Math.max(5, u.minutes + +v));
    if (k === 'cat') u.category = v;
    if (k === 'amb') u.ambient = v;
    renderLayer();
  },
  startFocus: () => startSession(),
  startBreak: () => startBreak(),
  skipBreak: () => startNextRound(),
  nextRound: () => startNextRound(),
  endPomo: () => { clearTimeout(ui.revealTimer); ui.reward = null; keepAwake(false); document.title = 'Ember Grove'; commit((s) => { s.pomo = null; s.activeBreak = null; }); },
  pause: () => { commit((s) => { s.activeSession.pausedAt = Date.now(); }); Sound.stopAmbient(); lastTimerText = ''; },
  resume: () => {
    Sound.unlock();
    commit((s) => { const a = s.activeSession; a.pausedTotal += (Date.now() - a.pausedAt) / 1000; a.pausedAt = null; });
    Sound.setAmbient(S.settings.ambient, S.settings.ambientVolume); lastTimerText = '';
  },
  cycleAmbient: () => {
    Sound.unlock();
    const keys = Object.keys(AMBIENCE), next = keys[(keys.indexOf(S.settings.ambient) + 1) % keys.length];
    commit((s) => { s.settings.ambient = next; });
    if (!S.activeSession.pausedAt) Sound.setAmbient(next, S.settings.ambientVolume);
    lastTimerText = '';
  },
  finish: () => {
    const a = S.activeSession, e = G.elapsed(a);
    if (e < 60) ui.dialog = { title: 'Just getting started', body: "Sessions shorter than a minute aren't saved.", buttons: [{ label: 'Keep going', act: 'closeDialog' }, { label: 'End without saving', act: 'discard', secondary: true, danger: true }] };
    else if (a.mode === 'countdown') ui.dialog = { title: 'Finish this session?', body: "Every minute you've focused is kept. Ending early is always okay.", buttons: [{ label: 'Finish and collect rewards', act: 'finishNow' }, { label: 'Keep going', act: 'closeDialog', secondary: true }] };
    else return finishSession();
    renderLayer();
  },
  finishNow: () => finishSession(),
  discard: () => { ui.dialog = null; Sound.stopAmbient(); keepAwake(false); document.title = 'Ember Grove'; commit((s) => { s.activeSession = null; }); },
  rewardTap: () => { revealNext(); scheduleReveal(); },
  rewardWear: (id) => { const c = byId(COSMETICS, id); commit((s) => G.equip(s, c, c.slot)); sfx('tap'); },
  rewardGo: (arg) => {
    clearTimeout(ui.revealTimer); ui.reward = null;
    if (S.pomo) { S.pomo = null; G.save(S); }
    if (arg === 'restore') ui.tab = 'world';
    if (arg === 'path') ui.tab = 'ember';
    render();
    if (arg) setTimeout(() => openSheet(arg), 250);
  },
  pickLandmark: (id) => { ui.restorePick = id; ui.restoreVariant = byId(LANDMARKS, id).variants[0].id; renderLayer(); },
  pickVariant: (id) => { ui.restoreVariant = id; renderLayer(); },
  doRestore: () => {
    const ch = commit((s) => G.restore(s, ui.restorePick, ui.restoreVariant));
    ui.sheet = null; ui.worldTarget = byId(LANDMARKS, ui.restorePick).x + 50; ui.worldMood = 'happy';
    render(); sfx('levelUp'); showBanner(ch);
  },
  pickPath: (p) => { ui.pathPick = p; renderLayer(); },
  doPath: () => { const ch = commit((s) => G.choosePath(s, ui.pathPick)); ui.sheet = null; ui.mood = 'celebrating'; render(); sfx('levelUp'); showBanner(ch); setTimeout(() => { ui.mood = 'idle'; render(); }, 3000); },
  visit: (id) => {
    const l = byId(LANDMARKS, id);
    ui.worldTarget = Math.max(30, Math.min(1570, l.x + (l.x < 200 ? 70 : -60))); ui.worldMood = 'curious';
    const dist = Math.abs(ui.worldTarget - ui.worldX);
    setTimeout(() => { ui.worldMood = S.restored[id] ? 'happy' : 'curious'; openSheet('landmark', id); }, Math.min(1600, 400 + dist * 1.6));
  },
  buyDecor: (id) => {
    const d = byId(DECORATIONS, id);
    if (S.seeds < d.cost) { ui.dialog = { title: 'Not enough Seeds yet', body: 'A few more focus sessions will get you there.', buttons: [{ label: 'OK', act: 'closeDialog' }] }; renderLayer(); return; }
    commit((s) => G.buyDecoration(s, d)); sfx('discover');
  },
  toggleDecor: (id) => commit((s) => { const i = s.hiddenDecorations.indexOf(id); i >= 0 ? s.hiddenDecorations.splice(i, 1) : s.hiddenDecorations.push(id); }),
  slot: (s) => { ui.slot = s; render(); },
  wear: (id) => {
    const c = id ? byId(COSMETICS, id) : null;
    if (c && !G.isCosmeticUnlocked(S, c)) {
      if (c.unlock.seeds) {
        ui.dialog = { title: `Get the ${c.name}?`, body: c.blurb, buttons: [
          { label: S.seeds >= c.unlock.seeds ? `Buy for ${c.unlock.seeds} Seeds` : `Needs ${c.unlock.seeds} Seeds (you have ${S.seeds})`, act: S.seeds >= c.unlock.seeds ? 'buyCosmetic' : 'closeDialog', arg: c.id },
          { label: 'Not now', act: 'closeDialog', secondary: true }] };
        renderLayer();
      }
      return;
    }
    commit((s) => G.equip(s, c, ui.slot)); sfx('tap');
  },
  buyCosmetic: (id) => { const c = byId(COSMETICS, id); ui.dialog = null; commit((s) => { if (G.buyCosmetic(s, c)) G.equip(s, c, c.slot); }); sfx('discover'); },
  rename: () => { ui.dialog = { title: 'Rename your companion', input: S.emberName, buttons: [{ label: 'Save', act: 'saveName' }, { label: 'Cancel', act: 'closeDialog', secondary: true }] }; renderLayer(); },
  saveName: () => { const v = (document.getElementById('dlgInput')?.value || '').trim().slice(0, 16); ui.dialog = null; commit((s) => { if (v) s.emberName = v; }); },
  journey: (id) => { ui.journey = id; ui.scroll.journey = 0; render(); },
  claim: (key) => {
    const q = [...G.quests(S, 'daily'), ...G.quests(S, 'weekly')].find((x) => x.claimKey === key);
    let ch = null;
    commit((s) => { if (G.claim(s, q)) ch = G.refreshMilestones(s); });
    sfx('discover'); showBanner(ch);
  },
  readChapter: (id) => { openSheet('chapter', id); if (!S.chaptersRead.includes(id)) { S.chaptersRead.push(id); G.save(S); } },
  chapterNext: () => {
    const c = byId(CHAPTERS, ui.sheet.arg);
    if (ui.chapterPage < c.pages.length - 1) { ui.chapterPage++; renderLayer(); } else { ui.sheet = null; render(); }
  },
  curio: (id) => { const c = byId(CURIOS, id); ui.dialog = { title: c.name, body: c.blurb, buttons: [{ label: 'Lovely', act: 'closeDialog' }] }; renderLayer(); },
  toggleSetting: (key) => commit((s) => { s.settings[key] = !s.settings[key]; }),
  stepSetting: (arg) => {
    const [key, d] = arg.split(':'), lim = key === 'dailyGoalMinutes' ? [15, 480] : [5, 180];
    if (key.startsWith('pomo')) { commit((s) => { s.settings[key] = clampPomo(key, s.settings[key] + +d); }); return; }
    commit((s) => { s.settings[key] = Math.min(lim[1], Math.max(lim[0], s.settings[key] + +d)); });
  },
  exportData: async () => {
    const data = JSON.stringify(S);
    try { await navigator.clipboard.writeText(data); ui.dialog = { title: 'Backup copied', body: 'Paste it into Notes (or anywhere safe). Use "Restore a backup" to bring it back.', buttons: [{ label: 'OK', act: 'closeDialog' }] }; }
    catch (e) { ui.dialog = { title: 'Copy this backup', input: data, buttons: [{ label: 'Done', act: 'closeDialog' }] }; }
    renderLayer();
  },
  importData: () => {
    const raw = prompt('Paste your Ember Grove backup:');
    if (!raw) return;
    try {
      const data = JSON.parse(raw);
      if (typeof data.xp !== 'number' || !Array.isArray(data.sessions)) throw new Error('bad');
      S = { ...G.newState(), ...data, settings: { ...G.defaultSettings(), ...data.settings } };
      G.save(S); ui.sheet = null; render();
    } catch (e) { alert("That doesn't look like an Ember Grove backup."); }
  },
  reset: () => {
    ui.dialog = { title: 'Start over?', body: "Your character, world and history will be reset. This can't be undone.", buttons: [{ label: 'Erase all progress', act: 'resetNow', danger: true, secondary: true }, { label: 'Cancel', act: 'closeDialog' }] };
    renderLayer();
  },
  resetNow: () => {
    const settings = S.settings;
    S = G.newState(); S.settings = settings; G.refreshMilestones(S); G.save(S);
    ui.dialog = null; ui.sheet = null; ui.tab = 'home'; render();
  },
  onboard: () => {
    Sound.unlock();
    if (ui.onboardStep < 2) { ui.onboardStep++; renderLayer(); return; }
    const v = (document.getElementById('nameInput')?.value || '').trim().slice(0, 16);
    commit((s) => { if (v) s.emberName = v; s.settings.hasOnboarded = true; G.refreshMilestones(s); });
    sfx('start');
  },
};

document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el || el.disabled) return;
  const fn = actions[el.dataset.act];
  if (fn) { e.preventDefault(); fn(el.dataset.arg); }
});

document.addEventListener('change', (e) => {
  const el = e.target.closest('[data-set]');
  if (!el) return;
  const key = el.dataset.set, val = el.type === 'range' ? +el.value : el.value;
  commit((s) => { s.settings[key] = val; });
  if (key === 'ambientVolume' && S.activeSession) Sound.setAmbient(S.settings.ambient, val);
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && e.target.id === 'dlgInput') actions.saveName();
  if (e.key === 'Enter' && e.target.id === 'nameInput') actions.onboard();
});

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    checkCompletion();
    if (S.activeSession && !S.activeSession.pausedAt) keepAwake(true);
    render();
  }
});
setInterval(checkCompletion, 1000);

// ---------------------------------------------------------------- Drawing loop
function sizeCanvas(c) {
  const r = c.getBoundingClientRect();
  if (!r.width || !r.height) return null;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
  if (c.width !== w || c.height !== h) { c.width = w; c.height = h; c.dataset.drawn = ''; }
  return { w: r.width, h: r.height, dpr };
}

function drawCanvas(c, t, still) {
  const kind = c.dataset.kind, anim = c.dataset.anim !== '0';
  if (kind !== 'grove' && (!anim || still) && c.dataset.drawn === '1') return;
  const sz = sizeCanvas(c);
  if (!sz) return;
  const ctx = c.getContext('2d'), { w, h, dpr } = sz;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, c.width, c.height);

  if (kind === 'ember') {
    const s = Math.min(w, h) / 200;
    ctx.setTransform(dpr * s, 0, 0, dpr * s, dpr * (w - 200 * s) / 2, dpr * (h - 200 * s) / 2);
    drawEmber(ctx, JSON.parse(c.dataset.a), c.dataset.mood, t, still || !anim);
  } else if (kind === 'companion') {
    const [cx, cy, span] = COMPANION_FRAMES[c.dataset.id], s = Math.min(w, h) / span;
    ctx.setTransform(dpr * s, 0, 0, dpr * s, dpr * (w / 2 - cx * s), dpr * (h / 2 - cy * s));
    drawCompanion(ctx, c.dataset.id, 2, true, false);
  } else if (kind === 'grove') {
    const live = c.dataset.live, yTop = +(c.dataset.ytop || 0), s = h / (WORLD_H - yTop);
    let vp = c.dataset.vp === 'auto' ? null : c.dataset.vp.split(',').map(Number);
    if (!vp) { const span = WORLD_H * w / h; vp = [300 - span / 2, 300 + span / 2]; }
    let scene = snap;
    let ex = 322, mood = ui.mood, boost = 0, phase = skyPhase();
    if (live === 'world') { ex = ui.worldX; mood = ui.worldMood; }
    if (live === 'break') { mood = S.activeBreak?.done ? 'happy' : 'sleepy'; scene = { ...snap, hearthLit: true }; boost = 0.15; }
    if (live === 'focus' && S.activeSession) {
      const a = S.activeSession, e = G.elapsed(a);
      phase = 'night'; mood = a.pausedAt ? 'sleepy' : 'focused';
      scene = { ...snap, hearthLit: true };
      boost = a.target ? G.progress(a) : Math.min(1, e / 3600);
    }
    ctx.setTransform(dpr * s, 0, 0, dpr * s, -vp[0] * dpr * s, -yTop * dpr * s);
    drawGrove(ctx, scene, { phase, viewport: vp, t, still, hearthBoost: boost });
    const es = +(c.dataset.es || 96), top = groundY(ex) + 52 - es * 0.91;
    ctx.save(); ctx.translate(ex - es / 2, top); ctx.scale(es / 200, es / 200);
    drawEmber(ctx, G.appearance(S), mood, t, still);
    ctx.restore();
  }
  c.dataset.drawn = '1';
}

function frame() {
  const t = (performance.now() / 1000) % 3600, still = reduceMotion();
  const d = ui.worldTarget - ui.worldX;
  if (Math.abs(d) > 0.5) ui.worldX += Math.sign(d) * Math.min(Math.abs(d), still ? 9999 : 6);
  else if (ui.worldMood === 'curious' && !ui.sheet) ui.worldMood = 'idle';
  for (const c of document.querySelectorAll('canvas[data-kind]')) drawCanvas(c, t, still);
  updateFocusText();
  if (ui.reward && ui.glowStart) {
    const el = document.getElementById('glowCount');
    if (el) el.textContent = `+${Math.round(ui.reward.glowTotal * Math.min(1, (performance.now() - ui.glowStart) / 700))} Glow`;
  }
  requestAnimationFrame(frame);
}

// ---------------------------------------------------------------- Boot
checkCompletion();
render();
if (S.activeSession && !S.activeSession.pausedAt) keepAwake(true);
requestAnimationFrame(frame);
if ('serviceWorker' in navigator && location.protocol.startsWith('http')) navigator.serviceWorker.register('sw.js').catch(() => {});
window.__ember = { get state() { return S; }, actions, G, ui, render };
