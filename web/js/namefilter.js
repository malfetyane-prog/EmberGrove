// Display-name safety filter. The same rules run in the database (see supabase/safety.sql),
// so a modified app still can't save a blocked name.

// Matched anywhere in the squashed name (letters only, look-alikes and digits mapped to letters).
const ANYWHERE = [
  'fuck', 'fuk', 'fck', 'phuck', 'shit', 'bitch', 'cunt', 'whore', 'slut', 'retard', 'porn', 'nazi', 'hitler',
  'penis', 'vagina', 'motherf', 'dickhead', 'cocksuck', 'bastard', 'wanker', 'twat', 'jizz', 'dildo',
  'sharmo', 'sharmu', 'manyak', 'manyok', 'metnak', 'mitnak', 'khawal', 'qahba', 'kahba',
  'شرموط', 'منيوك', 'متناك', 'قحب', 'عرصه', 'كسمك', 'كسختك',
];
// Same, but checked before repeated letters are collapsed (these words contain doubles).
const ANYWHERE_DOUBLE = ['nigger', 'nigga', 'faggot', 'asshole', 'pussy', 'killyourself'];
// Checked after collapsing repeats (so "fuuuck" and "ashole" are caught).
const ANYWHERE_SINGLE = ['ashole', 'pusy', 'fagot', 'kilyourself'];
// Whole words only, to avoid flagging innocent names (e.g. "Cassie", "Dickens", "Nicole").
const WORDS = [
  'ass', 'arse', 'dick', 'cock', 'tits', 'cum', 'sex', 'fag', 'hoe', 'rape', 'kys', 'kkk', 'damn', 'piss', 'crap', 'nig',
  'kos', 'koss', 'kuss', 'kus', 'zeb', 'zib', 'zebi', 'zibi', 'ayre', 'ayri', 'neek', 'teez', 'tiz', '3ars', '2a7ba', 'a7ba',
  'كس', 'كسك', 'طيز', 'زب', 'زبي', 'نيك', 'عرص', 'خول', 'قحبه', 'شرموطه', 'منيك',
];
// Innocent words that contain a blocked fragment; removed before checking.
const SAFE = ['scunthorpe', 'pussycat', 'penistone', 'cockburn', 'hancock'];
const RESERVED = ['admin', 'moderator', 'official', 'support', 'embergrove'];

const LOOKALIKE = { 'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'у': 'y', 'х': 'x', 'і': 'i', 'ј': 'j', 'ѕ': 's', 'к': 'k', 'м': 'm', 'т': 't', 'в': 'b', 'н': 'h', 'ƒ': 'f' };
const LEET = { 0: 'o', 1: 'i', 3: 'e', 4: 'a', 5: 's', 7: 't', 8: 'b', 9: 'g', '@': 'a', $: 's', '!': 'i', '|': 'i', '+': 't' };

function base(name) {
  let s = name.normalize('NFKD').replace(/[̀-ͯ​-‏⁠﻿]/g, '').toLowerCase();
  s = s.replace(/./gu, (c) => LOOKALIKE[c] || c);
  // Arabic: unify letter forms, drop diacritics and the stretching character.
  return s.replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه').replace(/[ً-ْـ]/g, '');
}

const LETTERS = /[^a-zء-ي]/g;

export function isNameClean(name) {
  const b = base(name);
  const leet = b.replace(/./g, (c) => LEET[c] || c);
  let flat = leet.replace(LETTERS, '');
  for (const w of SAFE) flat = flat.replaceAll(w, '');
  const single = flat.replace(/(.)\1+/g, '$1');
  if (ANYWHERE.some((w) => flat.includes(w) || single.includes(w))) return false;
  if (ANYWHERE_DOUBLE.some((w) => flat.includes(w))) return false;
  if (ANYWHERE_SINGLE.some((w) => single.includes(w))) return false;
  if (RESERVED.some((w) => flat.includes(w))) return false;
  const tokens = new Set([...b.split(/[^a-z0-9ء-ي]+/), ...leet.split(/[^a-zء-ي]+/), ...leet.split(/[^a-zء-ي]+/).map((t) => t.replace(/(.)\1+/g, '$1'))]);
  return !WORDS.some((w) => tokens.has(w));
}
