// Generate habit_days for all users.
// Called by Supabase cron at midnight (per-timezone) or on-demand when the app opens.
//
// For each active user_habit with a currently-active schedule, if today's
// day-of-week is in the schedule's `days` array and no habit_day exists yet
// for that (user_habit_id, date), insert one with target_snap/unit_snap frozen.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: ["secret"] }, async (req, ctx) => {
    const admin = ctx.supabaseAdmin;

    // Allow caller to specify a date (for backfills), default to today
    let targetDate: string;
    try {
      const body = await req.json();
      targetDate = body?.date ?? new Date().toISOString().slice(0, 10);
    } catch {
      targetDate = new Date().toISOString().slice(0, 10);
    }

    // JS Date.getDay(): 0=Sun, 1=Mon...6=Sat
    // Our schema: 0=Mon, 1=Tue...6=Sun
    // Convert JS day-of-week to our schema's convention
    const jsDay = new Date(targetDate + "T12:00:00Z").getUTCDay();
    const schemaDow = jsDay === 0 ? 6 : jsDay - 1; // Sun=6, Mon=0, etc.

    // Find all active user_habits with a currently-active schedule
    // where today's day-of-week is in the schedule's days array
    // and no habit_day exists yet for this date
    const { data: schedules, error: scheduleErr } = await admin
      .from("user_habit_schedules")
      .select(`
        id,
        user_habit_id,
        target,
        days,
        user_habits!inner (
          id,
          habit_id,
          archived_at,
          habits!inner ( unit )
        )
      `)
      .lte("effective_from", targetDate)
      .or(`effective_to.is.null,effective_to.gt.${targetDate}`)
      .is("user_habits.archived_at", null);

    if (scheduleErr) {
      return Response.json({ error: scheduleErr.message }, { status: 500 });
    }

    // Filter to schedules where today's DOW is included
    const applicable = (schedules ?? []).filter((s: any) => {
      const days: number[] = s.days ?? [];
      // Empty days array = daily
      return days.length === 0 || days.includes(schemaDow);
    });

    if (applicable.length === 0) {
      return Response.json({ inserted: 0, date: targetDate });
    }

    // Check which habit_days already exist for these user_habit_ids on this date
    const userHabitIds = applicable.map((s: any) => s.user_habit_id);
    const { data: existing } = await admin
      .from("habit_days")
      .select("user_habit_id")
      .in("user_habit_id", userHabitIds)
      .eq("date", targetDate);

    const existingSet = new Set((existing ?? []).map((e: any) => e.user_habit_id));

    // Build rows to insert
    const rows = applicable
      .filter((s: any) => !existingSet.has(s.user_habit_id))
      .map((s: any) => ({
        user_habit_id: s.user_habit_id,
        schedule_id: s.id,
        date: targetDate,
        target_snap: s.target,
        unit_snap: s.user_habits.habits.unit,
        status: "pending",
        pct: 0,
        sum: 0,
      }));

    if (rows.length === 0) {
      return Response.json({ inserted: 0, date: targetDate });
    }

    const { error: insertErr } = await admin
      .from("habit_days")
      .insert(rows);

    if (insertErr) {
      return Response.json({ error: insertErr.message }, { status: 500 });
    }

    return Response.json({ inserted: rows.length, date: targetDate });
  }),
};
