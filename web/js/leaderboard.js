// Leaderboard: anonymous Supabase accounts (no email), one public row per player.
import { SUPABASE_URL, SUPABASE_KEY } from './config.js';
import { isNameClean } from './namefilter.js';

export const enabled = () => !!SUPABASE_KEY;

export const FRIENDLIER = 'Please choose a friendlier name.';
export function nameProblem(name) {
  const n = name.trim();
  if (n.length < 2) return 'Use at least 2 characters.';
  if (n.length > 20) return 'Keep it to 20 characters or fewer.';
  if (!isNameClean(n)) return FRIENDLIER;
  return null;
}

/** The database rejects blocked names too (layer 2); turn its error into the same friendly text. */
export const isNameRejection = (e) => /name_not_allowed/i.test(e?.message || '');

async function call(path, { method = 'GET', body, token, prefer } = {}) {
  const headers = { apikey: SUPABASE_KEY, 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (prefer) headers.Prefer = prefer;
  const res = await fetch(SUPABASE_URL + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error((data && (data.msg || data.message || data.error_description || data.error)) || `HTTP ${res.status}`);
  return data;
}

function keepSession(profile, d) {
  profile.userId = d.user?.id || profile.userId;
  profile.accessToken = d.access_token;
  profile.refreshToken = d.refresh_token;
  profile.expiresAt = Date.now() + (d.expires_in || 3600) * 1000 - 60e3;
}

/** Returns a valid access token, signing in anonymously the first time. Mutates profile. */
async function token(profile) {
  if (profile.accessToken && Date.now() < profile.expiresAt) return profile.accessToken;
  if (profile.refreshToken) {
    try {
      keepSession(profile, await call('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: profile.refreshToken } }));
      return profile.accessToken;
    } catch (e) { /* fall through to a fresh anonymous account */ }
  }
  keepSession(profile, await call('/auth/v1/signup', { method: 'POST', body: { data: {} } }));
  return profile.accessToken;
}

let circleReady = true; // false until the focus circle SQL has been run

/** Creates or updates this player's public row. */
export async function publish(profile, row) {
  const t = await token(profile);
  const send = (body) => call('/rest/v1/players?on_conflict=id', {
    method: 'POST', token: t, prefer: 'resolution=merge-duplicates,return=representation',
    body: { id: profile.userId, ...body, updated_at: new Date().toISOString() },
  });
  const { focus_since, focus_until, ...stats } = row;
  let res;
  try { res = await send(circleReady ? row : stats); }
  catch (e) {
    if (!/focus_/.test(e.message)) throw e;
    circleReady = false;
    res = await send(stats);
  }
  if (res && res[0]) profile.tag = res[0].tag;
  return res && res[0];
}

/** Top players for this week (by week_minutes) or all time (by total_minutes). */
export async function fetchBoard(profile, scope, weekKey) {
  const t = profile.userId ? await token(profile) : null;
  const cols = 'id,name,tag,level,stage,appearance,week_minutes,total_minutes';
  const q = scope === 'week'
    ? `week_key=eq.${encodeURIComponent(weekKey)}&week_minutes=gt.0&order=week_minutes.desc,updated_at.asc`
    : 'total_minutes=gt.0&order=total_minutes.desc,updated_at.asc';
  try {
    return await call(`/rest/v1/players?select=${cols}&${q}&hidden=is.false&banned=is.false&limit=50`, { token: t });
  } catch (e) {
    // Before the safety SQL is installed the hidden/banned columns don't exist yet.
    if (/hidden|banned/.test(e.message)) return call(`/rest/v1/players?select=${cols}&${q}&limit=50`, { token: t });
    throw e;
  }
}

/** Players focusing right now, longest-focusing first. */
export async function fetchCircle(profile) {
  const t = profile.userId ? await token(profile) : null;
  return call(`/rest/v1/players?select=id,name,appearance,focus_since&focus_until=gt.${encodeURIComponent(new Date().toISOString())}`
    + '&hidden=is.false&banned=is.false&order=focus_since.asc&limit=30', { token: t });
}

/** Reports a player's name. Three reports from different players hide it automatically. */
export async function report(profile, playerId) {
  const t = await token(profile);
  try {
    await call('/rest/v1/reports', { method: 'POST', token: t, prefer: 'return=minimal', body: { player: playerId } });
  } catch (e) {
    if (!/duplicate|23505/i.test(e.message)) throw e; // already reported by this player: fine
  }
}

export async function leave(profile) {
  const t = await token(profile);
  await call(`/rest/v1/players?id=eq.${profile.userId}`, { method: 'DELETE', token: t });
}
