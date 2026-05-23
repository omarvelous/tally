-- Tally: Initial Schema
-- Shared-habits model: habits are global, users adopt them via user_habits.

-- ============================================================
-- Extensions
-- ============================================================
create extension if not exists "uuid-ossp" with schema extensions;

-- ============================================================
-- profiles
-- ============================================================
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  initials    text not null default '',
  timezone    text not null default 'America/New_York',
  created_at  timestamptz not null default now()
);

comment on table public.profiles is 'Extends Supabase Auth. One row per user.';

-- ============================================================
-- categories
-- ============================================================
create table public.categories (
  id         uuid primary key default extensions.uuid_generate_v4(),
  name       text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

comment on table public.categories is 'Server-managed groupings for browsing habits.';

-- ============================================================
-- habits  (GLOBAL — shared across all users)
-- ============================================================
create table public.habits (
  id              uuid primary key default extensions.uuid_generate_v4(),
  category_id     uuid not null references public.categories(id),
  name            text not null,
  description     text not null default '',
  type            text not null check (type in ('check', 'count', 'timer', 'numeric', 'yesno')),
  unit            text,          -- locked for all users; NULL for check/yesno
  default_target  numeric,       -- suggested starting target
  default_days    int[] not null default '{0,1,2,3,4,5,6}',  -- 0=Mon..6=Sun
  default_times   text[] not null default '{"all-day"}',
  is_popular      boolean not null default false,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now()
);

comment on table public.habits is 'Global habit catalog. Shared across all users. Type and unit are immutable.';

-- ============================================================
-- user_habits  (JOIN: user ↔ habit)
-- ============================================================
create table public.user_habits (
  id          uuid primary key default extensions.uuid_generate_v4(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  habit_id    uuid not null references public.habits(id),
  sort_order  int not null default 0,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  unique (profile_id, habit_id)
);

comment on table public.user_habits is 'Links a user to a habit they adopted. One row per user per habit.';

create index idx_user_habits_profile on public.user_habits(profile_id);
create index idx_user_habits_habit   on public.user_habits(habit_id);

-- ============================================================
-- user_habit_schedules
-- ============================================================
create table public.user_habit_schedules (
  id              uuid primary key default extensions.uuid_generate_v4(),
  user_habit_id   uuid not null references public.user_habits(id) on delete cascade,
  target          numeric,       -- user's personal target; NULL for check/yesno
  days            int[] not null default '{0,1,2,3,4,5,6}',
  times           text[] not null default '{"all-day"}',
  effective_from  date not null,
  effective_to    date,          -- NULL = currently active
  created_at      timestamptz not null default now()
);

comment on table public.user_habit_schedules is 'Temporal versioning of a user''s schedule for an adopted habit. No unit column — inherited from habits.unit.';

create index idx_uhs_user_habit  on public.user_habit_schedules(user_habit_id);
create index idx_uhs_effective   on public.user_habit_schedules(user_habit_id, effective_from, effective_to);

-- ============================================================
-- habit_days  (materialized occurrences)
-- ============================================================
create table public.habit_days (
  id              uuid primary key default extensions.uuid_generate_v4(),
  user_habit_id   uuid not null references public.user_habits(id) on delete cascade,
  schedule_id     uuid not null references public.user_habit_schedules(id),
  date            date not null,
  target_snap     numeric,       -- frozen at generation time
  unit_snap       text,          -- frozen from habits.unit at generation time
  status          text not null default 'pending'
                    check (status in ('pending', 'partial', 'done', 'skipped')),
  pct             numeric not null default 0,
  sum             numeric not null default 0,
  created_at      timestamptz not null default now(),

  unique (user_habit_id, date)
);

comment on table public.habit_days is 'One row per user-habit per active day. THE source of truth for "was this habit due on date X?"';

create index idx_habit_days_date     on public.habit_days(date);
create index idx_habit_days_lookup   on public.habit_days(user_habit_id, date);

-- ============================================================
-- log_entries
-- ============================================================
create table public.log_entries (
  id           uuid primary key default extensions.uuid_generate_v4(),
  habit_day_id uuid not null references public.habit_days(id) on delete cascade,
  value        numeric not null,  -- 1.0 for check/yesno; amount for count/timer/numeric
  logged_at    timestamptz not null default now(),
  timezone     text not null default 'America/New_York',
  deleted_at   timestamptz,       -- soft delete
  created_at   timestamptz not null default now()
);

comment on table public.log_entries is 'Immutable event log. What the user actually did.';

create index idx_log_entries_hd on public.log_entries(habit_day_id);

-- ============================================================
-- day_summaries
-- ============================================================
create table public.day_summaries (
  id          uuid primary key default extensions.uuid_generate_v4(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  date        date not null,
  total       int not null default 0,
  done        int not null default 0,
  partial     int not null default 0,
  overdue     int not null default 0,
  pct         numeric not null default 0,
  streak_day  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  unique (profile_id, date)
);

comment on table public.day_summaries is 'Cached daily rollup per user per day.';

create index idx_day_summaries_lookup on public.day_summaries(profile_id, date);

-- ============================================================
-- preferences
-- ============================================================
create table public.preferences (
  id              uuid primary key default extensions.uuid_generate_v4(),
  profile_id      uuid not null unique references public.profiles(id) on delete cascade,
  theme           text not null default 'system' check (theme in ('system', 'light', 'dark')),
  density         text not null default 'regular' check (density in ('regular', 'compact')),
  quiet_start     time,
  quiet_end       time,
  notif_enabled   boolean not null default true,
  updated_at      timestamptz not null default now()
);

comment on table public.preferences is 'Per-user settings. Singleton per profile.';

-- ============================================================
-- Trigger: auto-create profile + preferences on signup
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));

  insert into public.preferences (profile_id)
  values (new.id);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Trigger: recompute habit_day status when log_entries change
-- ============================================================
create or replace function public.recompute_habit_day()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  hd_id uuid;
  new_sum numeric;
  snap_target numeric;
  new_pct numeric;
  new_status text;
begin
  -- Determine the habit_day_id from the affected row
  if tg_op = 'DELETE' then
    hd_id := old.habit_day_id;
  else
    hd_id := new.habit_day_id;
  end if;

  -- Sum active (non-deleted) log entries
  select coalesce(sum(le.value), 0)
  into new_sum
  from public.log_entries le
  where le.habit_day_id = hd_id
    and le.deleted_at is null;

  -- Get the target snapshot
  select hd.target_snap
  into snap_target
  from public.habit_days hd
  where hd.id = hd_id;

  -- Compute pct
  if snap_target is null or snap_target = 0 then
    -- check/yesno: any value >= 1 = done
    new_pct := case when new_sum >= 1 then 1.0 else 0.0 end;
  else
    new_pct := new_sum / snap_target;
  end if;

  -- Derive status
  if new_pct >= 1.0 then
    new_status := 'done';
  elsif new_pct > 0 then
    new_status := 'partial';
  else
    new_status := 'pending';
  end if;

  -- Update habit_day
  update public.habit_days
  set sum = new_sum,
      pct = new_pct,
      status = new_status
  where id = hd_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger on_log_entry_change
  after insert or update or delete on public.log_entries
  for each row execute function public.recompute_habit_day();

-- ============================================================
-- Trigger: recompute day_summary when habit_days change
-- ============================================================
create or replace function public.recompute_day_summary()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  p_id uuid;
  d date;
  r record;
begin
  -- Get profile_id and date from the affected habit_day
  if tg_op = 'DELETE' then
    select uh.profile_id into p_id
    from public.user_habits uh
    where uh.id = old.user_habit_id;
    d := old.date;
  else
    select uh.profile_id into p_id
    from public.user_habits uh
    where uh.id = new.user_habit_id;
    d := new.date;
  end if;

  if p_id is null then
    return coalesce(new, old);
  end if;

  -- Aggregate habit_days for this user+date
  select
    count(*)::int as total,
    count(*) filter (where hd.status = 'done')::int as done,
    count(*) filter (where hd.status = 'partial')::int as partial,
    count(*) filter (where hd.status = 'pending')::int as overdue
  into r
  from public.habit_days hd
  join public.user_habits uh on uh.id = hd.user_habit_id
  where uh.profile_id = p_id
    and hd.date = d;

  -- Upsert day_summary
  insert into public.day_summaries (profile_id, date, total, done, partial, overdue, pct, streak_day)
  values (
    p_id, d, r.total, r.done, r.partial, r.overdue,
    case when r.total = 0 then 0 else r.done::numeric / r.total end,
    r.total > 0 and r.done = r.total
  )
  on conflict (profile_id, date) do update set
    total      = excluded.total,
    done       = excluded.done,
    partial    = excluded.partial,
    overdue    = excluded.overdue,
    pct        = excluded.pct,
    streak_day = excluded.streak_day,
    updated_at = now();

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger on_habit_day_change
  after insert or update or delete on public.habit_days
  for each row execute function public.recompute_day_summary();

-- ============================================================
-- Trigger: updated_at auto-touch
-- ============================================================
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger touch_user_habits_updated_at
  before update on public.user_habits
  for each row execute function public.touch_updated_at();

create trigger touch_day_summaries_updated_at
  before update on public.day_summaries
  for each row execute function public.touch_updated_at();

create trigger touch_preferences_updated_at
  before update on public.preferences
  for each row execute function public.touch_updated_at();
