-- Ember Grove leaderboard safety. Run once in Supabase → SQL Editor (safe to re-run).
-- Layer 2: the database rejects blocked names, even from a modified app.
-- Layer 3: players can report names; 3 reports hide a name automatically.
-- Layer 4: you can set `banned = true` on any player in Table Editor; players can't undo it.

-- Same rules as web/js/namefilter.js
create or replace function public.name_is_clean(raw text) returns boolean
language plpgsql stable as $$
declare
  anywhere text[] := array['fuck', 'fuk', 'fck', 'phuck', 'shit', 'bitch', 'cunt', 'whore', 'slut', 'retard', 'porn', 'nazi', 'hitler', 'penis', 'vagina', 'motherf', 'dickhead', 'cocksuck', 'bastard', 'wanker', 'twat', 'jizz', 'dildo', 'sharmo', 'sharmu', 'manyak', 'manyok', 'metnak', 'mitnak', 'khawal', 'qahba', 'kahba', 'شرموط', 'منيوك', 'متناك', 'قحب', 'عرصه', 'كسمك', 'كسختك'];
  anywhere_double text[] := array['nigger', 'nigga', 'faggot', 'asshole', 'pussy', 'killyourself'];
  anywhere_single text[] := array['ashole', 'pusy', 'fagot', 'kilyourself'];
  words text[] := array['ass', 'arse', 'dick', 'cock', 'tits', 'cum', 'sex', 'fag', 'hoe', 'rape', 'kys', 'kkk', 'damn', 'piss', 'crap', 'nig', 'kos', 'koss', 'kuss', 'kus', 'zeb', 'zib', 'zebi', 'zibi', 'ayre', 'ayri', 'neek', 'teez', 'tiz', '3ars', '2a7ba', 'a7ba', 'كس', 'كسك', 'طيز', 'زب', 'زبي', 'نيك', 'عرص', 'خول', 'قحبه', 'شرموطه', 'منيك'];
  safe text[] := array['scunthorpe', 'pussycat', 'penistone', 'cockburn', 'hancock'];
  reserved text[] := array['admin', 'moderator', 'official', 'support', 'embergrove'];
  b text; leet text; flat text; single text; w text; tokens text[];
begin
  b := lower(normalize(raw, NFKD));
  b := regexp_replace(b, '[\u0300-\u036f\u200b-\u200f\u2060\ufeff]', '', 'g');
  b := translate(b, 'аеорсухіјѕкмтвнƒ', 'aeopcyxijskmtbhf');
  b := translate(b, 'أإآىة', 'ااايه');
  b := regexp_replace(b, '[\u064b-\u0652\u0640]', '', 'g');
  leet := translate(b, '01345789@$!|+', 'oieastbgasiit');
  flat := regexp_replace(leet, '[^a-z\u0621-\u064a]', '', 'g');
  foreach w in array safe loop flat := replace(flat, w, ''); end loop;
  single := regexp_replace(flat, '(.)\1+', '\1', 'g');
  foreach w in array anywhere loop
    if strpos(flat, w) > 0 or strpos(single, w) > 0 then return false; end if;
  end loop;
  foreach w in array anywhere_double loop if strpos(flat, w) > 0 then return false; end if; end loop;
  foreach w in array anywhere_single loop if strpos(single, w) > 0 then return false; end if; end loop;
  foreach w in array reserved loop if strpos(flat, w) > 0 then return false; end if; end loop;
  tokens := regexp_split_to_array(b, '[^a-z0-9\u0621-\u064a]+')
         || regexp_split_to_array(leet, '[^a-z\u0621-\u064a]+')
         || array(select regexp_replace(x, '(.)\1+', '\1', 'g') from unnest(regexp_split_to_array(leet, '[^a-z\u0621-\u064a]+')) x);
  return not (tokens && words);
end $$;

alter table public.players add column if not exists hidden boolean not null default false;
alter table public.players add column if not exists banned boolean not null default false;

create table if not exists public.reports (
  reporter uuid not null default auth.uid() references auth.users (id) on delete cascade,
  player uuid not null references public.players (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reporter, player)
);
alter table public.reports enable row level security;
drop policy if exists "Players can report others" on public.reports;
create policy "Players can report others" on public.reports
  for insert with check (reporter = auth.uid() and player <> auth.uid());

-- Reject blocked names; a new (clean) name clears report-based hiding, but never a ban.
create or replace function public.players_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.name_is_clean(new.name) then
    raise exception 'name_not_allowed' using hint = 'Please choose a friendlier name.';
  end if;
  if tg_op = 'UPDATE' and new.name is distinct from old.name then
    new.hidden := false;
    delete from public.reports where player = new.id;
  end if;
  return new;
end $$;
drop trigger if exists players_guard on public.players;
create trigger players_guard before insert or update on public.players
  for each row execute function public.players_guard();

-- Hide a name once 3 different players report it.
create or replace function public.reports_autohide() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.reports where player = new.player) >= 3 then
    update public.players set hidden = true where id = new.player;
  end if;
  return new;
end $$;
drop trigger if exists reports_autohide on public.reports;
create trigger reports_autohide after insert on public.reports
  for each row execute function public.reports_autohide();

-- Players may only write their own stats, never `hidden`, `banned` or `tag`.
revoke insert, update on public.players from anon, authenticated;
grant insert (id, name, level, stage, appearance, week_key, week_minutes, total_minutes, updated_at) on public.players to authenticated;
grant update (id, name, level, stage, appearance, week_key, week_minutes, total_minutes, updated_at) on public.players to authenticated;
grant insert (player) on public.reports to authenticated;

-- Hide any names already on the board that break the rules.
update public.players set hidden = true where not public.name_is_clean(name);

notify pgrst, 'reload schema';
