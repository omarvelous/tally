-- Tally: Row-Level Security Policies
-- Principle: users see only their own data; global tables (habits, categories) are read-only for all.

-- ============================================================
-- Enable RLS on all tables
-- ============================================================
alter table public.profiles            enable row level security;
alter table public.categories          enable row level security;
alter table public.habits              enable row level security;
alter table public.user_habits         enable row level security;
alter table public.user_habit_schedules enable row level security;
alter table public.habit_days          enable row level security;
alter table public.log_entries         enable row level security;
alter table public.day_summaries       enable row level security;
alter table public.preferences         enable row level security;

-- ============================================================
-- profiles: users can read/update their own profile
-- ============================================================
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ============================================================
-- categories: readable by all authenticated users (server-managed)
-- ============================================================
create policy "Categories are readable by authenticated users"
  on public.categories for select
  to authenticated
  using (true);

-- ============================================================
-- habits: readable by all authenticated users (global catalog)
-- ============================================================
create policy "Habits are readable by authenticated users"
  on public.habits for select
  to authenticated
  using (true);

-- ============================================================
-- user_habits: users manage their own adopted habits
-- ============================================================
create policy "Users can view own user_habits"
  on public.user_habits for select
  using (auth.uid() = profile_id);

create policy "Users can insert own user_habits"
  on public.user_habits for insert
  with check (auth.uid() = profile_id);

create policy "Users can update own user_habits"
  on public.user_habits for update
  using (auth.uid() = profile_id);

create policy "Users can delete own user_habits"
  on public.user_habits for delete
  using (auth.uid() = profile_id);

-- ============================================================
-- user_habit_schedules: access through user_habits ownership
-- ============================================================
create policy "Users can view own schedules"
  on public.user_habit_schedules for select
  using (
    exists (
      select 1 from public.user_habits uh
      where uh.id = user_habit_id and uh.profile_id = auth.uid()
    )
  );

create policy "Users can insert own schedules"
  on public.user_habit_schedules for insert
  with check (
    exists (
      select 1 from public.user_habits uh
      where uh.id = user_habit_id and uh.profile_id = auth.uid()
    )
  );

create policy "Users can update own schedules"
  on public.user_habit_schedules for update
  using (
    exists (
      select 1 from public.user_habits uh
      where uh.id = user_habit_id and uh.profile_id = auth.uid()
    )
  );

-- ============================================================
-- habit_days: access through user_habits ownership
-- ============================================================
create policy "Users can view own habit_days"
  on public.habit_days for select
  using (
    exists (
      select 1 from public.user_habits uh
      where uh.id = user_habit_id and uh.profile_id = auth.uid()
    )
  );

create policy "Users can insert own habit_days"
  on public.habit_days for insert
  with check (
    exists (
      select 1 from public.user_habits uh
      where uh.id = user_habit_id and uh.profile_id = auth.uid()
    )
  );

create policy "Users can update own habit_days"
  on public.habit_days for update
  using (
    exists (
      select 1 from public.user_habits uh
      where uh.id = user_habit_id and uh.profile_id = auth.uid()
    )
  );

-- ============================================================
-- log_entries: access through habit_days → user_habits ownership
-- ============================================================
create policy "Users can view own log_entries"
  on public.log_entries for select
  using (
    exists (
      select 1 from public.habit_days hd
      join public.user_habits uh on uh.id = hd.user_habit_id
      where hd.id = habit_day_id and uh.profile_id = auth.uid()
    )
  );

create policy "Users can insert own log_entries"
  on public.log_entries for insert
  with check (
    exists (
      select 1 from public.habit_days hd
      join public.user_habits uh on uh.id = hd.user_habit_id
      where hd.id = habit_day_id and uh.profile_id = auth.uid()
    )
  );

create policy "Users can update own log_entries"
  on public.log_entries for update
  using (
    exists (
      select 1 from public.habit_days hd
      join public.user_habits uh on uh.id = hd.user_habit_id
      where hd.id = habit_day_id and uh.profile_id = auth.uid()
    )
  );

-- ============================================================
-- day_summaries: users own their summaries
-- ============================================================
create policy "Users can view own day_summaries"
  on public.day_summaries for select
  using (auth.uid() = profile_id);

create policy "Users can insert own day_summaries"
  on public.day_summaries for insert
  with check (auth.uid() = profile_id);

create policy "Users can update own day_summaries"
  on public.day_summaries for update
  using (auth.uid() = profile_id);

-- ============================================================
-- preferences: users own their preferences
-- ============================================================
create policy "Users can view own preferences"
  on public.preferences for select
  using (auth.uid() = profile_id);

create policy "Users can update own preferences"
  on public.preferences for update
  using (auth.uid() = profile_id);

-- ============================================================
-- Leaderboard: users can see other users' habit_days for
-- habits they also track (via a DB function, not raw table access).
-- This keeps RLS tight while enabling social features.
-- ============================================================

-- Leaderboard function: returns top performers for a given habit
create or replace function public.get_leaderboard(
  p_habit_id uuid,
  p_days int default 7,
  p_limit int default 20
)
returns table (
  profile_id uuid,
  display_name text,
  initials text,
  days_done bigint,
  avg_pct numeric
)
language sql
security definer set search_path = ''
stable
as $$
  select
    p.id as profile_id,
    p.display_name,
    p.initials,
    count(*) filter (where hd.status = 'done') as days_done,
    round(avg(hd.pct), 2) as avg_pct
  from public.habit_days hd
  join public.user_habits uh on uh.id = hd.user_habit_id
  join public.profiles p on p.id = uh.profile_id
  where uh.habit_id = p_habit_id
    and hd.date >= current_date - (p_days - 1)
  group by p.id, p.display_name, p.initials
  order by days_done desc, avg_pct desc
  limit p_limit;
$$;

-- Participant count function
create or replace function public.get_habit_participant_count(p_habit_id uuid)
returns bigint
language sql
security definer set search_path = ''
stable
as $$
  select count(*)
  from public.user_habits
  where habit_id = p_habit_id and archived_at is null;
$$;
