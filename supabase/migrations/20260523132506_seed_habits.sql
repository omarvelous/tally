-- Tally: Seed global habits and categories
-- Derived from task_templates.json. Stable UUIDs via uuid_generate_v5 (deterministic).

-- ============================================================
-- Categories
-- ============================================================
insert into public.categories (id, name, sort_order) values
  (extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),       'Health & Fitness',      0),
  (extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:productivity'), 'Productivity',          1),
  (extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:selfcare'),     'Self-care & Wellness',  2);

-- ============================================================
-- Habits
-- ============================================================
-- day mapping: 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun
-- "daily"    → {0,1,2,3,4,5,6}
-- "weekdays" → {0,1,2,3,4}
-- "mwf"      → {0,2,4}

insert into public.habits (id, category_id, name, description, type, unit, default_target, default_days, default_times, is_popular, sort_order) values
  -- Health & Fitness
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:water'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Drink water', 'Stay hydrated throughout the day',
    'count', 'oz', 64,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    true, 0
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:pushups'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Push-ups', 'Build upper body strength',
    'count', 'reps', 50,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    false, 1
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:walk'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Walk', 'Get moving every day',
    'timer', 'min', 30,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    true, 2
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:stretch'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Stretch', 'Start your day limber',
    'yesno', null, null,
    '{0,1,2,3,4,5,6}', '{"08:00"}',
    false, 3
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:weighin'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Weigh-in', 'Track your weight daily',
    'numeric', 'lbs', null,
    '{0,1,2,3,4,5,6}', '{"07:30"}',
    false, 4
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:vitamins'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Take vitamins', 'Don''t forget your supplements',
    'check', null, null,
    '{0,1,2,3,4,5,6}', '{"08:00"}',
    true, 5
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:meditate'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Meditate', 'Calm your mind',
    'timer', 'min', 10,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    true, 6
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:workout'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Workout', 'Hit the gym',
    'check', null, null,
    '{0,2,4}', '{"all-day"}',
    false, 7
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:sleep'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:health'),
    'Sleep 8 hours', 'Prioritize rest',
    'yesno', null, null,
    '{0,1,2,3,4,5,6}', '{"22:00"}',
    false, 8
  ),

  -- Productivity
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:read'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:productivity'),
    'Read', 'Build a reading habit',
    'timer', 'min', 20,
    '{0,1,2,3,4,5,6}', '{"21:00"}',
    true, 0
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:journal'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:productivity'),
    'Journal', 'Reflect on your day',
    'check', null, null,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    true, 1
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:deepwork'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:productivity'),
    'Deep work', 'Focused, distraction-free work',
    'timer', 'min', 120,
    '{0,1,2,3,4}', '{"all-day"}',
    false, 2
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:nosocial'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:productivity'),
    'No social media', 'Reclaim your attention',
    'yesno', null, null,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    false, 3
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:study'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:productivity'),
    'Study', 'Dedicated learning time',
    'timer', 'min', 60,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    false, 4
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:language'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:productivity'),
    'Practice language', 'Consistency beats intensity',
    'timer', 'min', 15,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    false, 5
  ),

  -- Self-care & Wellness
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:skincare'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:selfcare'),
    'Skincare routine', 'Morning and night',
    'check', null, null,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    false, 0
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:floss'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:selfcare'),
    'Floss', 'Protect your teeth',
    'check', null, null,
    '{0,1,2,3,4,5,6}', '{"22:00"}',
    false, 1
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:gratitude'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:selfcare'),
    'Gratitude', 'Note what you''re thankful for',
    'check', null, null,
    '{0,1,2,3,4,5,6}', '{"all-day"}',
    false, 2
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:coldshower'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:selfcare'),
    'Cold shower', 'Build mental toughness',
    'yesno', null, null,
    '{0,1,2,3,4,5,6}', '{"07:00"}',
    false, 3
  ),
  (
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'habit:screenfree'),
    extensions.uuid_generate_v5(extensions.uuid_nil(), 'category:selfcare'),
    'Screen-free time', 'Wind down before bed',
    'timer', 'min', 30,
    '{0,1,2,3,4,5,6}', '{"20:00"}',
    false, 4
  );
