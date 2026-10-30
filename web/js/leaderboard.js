// Leaderboard: anonymous Supabase accounts (no email), one public row per player.
import { SUPABASE_URL, SUPABASE_KEY } from './config.js';

export const enabled = () => !!SUPABASE_KEY;

const BLOCKED = ['fuck', 'shit', 'bitch', 'cunt', 'nigg', 'fag', 'rape', 'nazi', 'whore', 'slut', 'dick', 'pussy', 'asshole', 'retard'];
export function nameProblem(name) {
  const n = name.trim();
  if (n.length < 2) return 'Use at least 2 characters.';
  if (n.length > 20) return 'Keep it to 20 characters or fewer.';
  const flat = n.toLowerCase().replace(/[^a-z]/g, '').replace(/0/g, 'o');
  if (BLOCKED.some((w) => flat.includes(w))) return 'Please choose a friendlier name.';
  return null;
}

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

/** Creates or updates this player's public row. */
export async function publish(profile, row) {
  const t = await token(profile);
  const res = await call('/rest/v1/players?on_conflict=id', {
    method: 'POST', token: t, prefer: 'resolution=merge-duplicates,return=representation',
    body: { id: profile.userId, ...row, updated_at: new Date().toISOString() },
  });
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
  return call(`/rest/v1/players?select=${cols}&${q}&limit=50`, { token: t });
}

export async function leave(profile) {
  const t = await token(profile);
  await call(`/rest/v1/players?id=eq.${profile.userId}`, { method: 'DELETE', token: t });
}
