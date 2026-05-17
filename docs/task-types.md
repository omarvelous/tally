# Task Types

Tally supports five task types, each with distinct logging UX and completion logic.

## Check

**Use case:** One-shot binary actions — did you do it or not?

- **Examples:** Take vitamins, make bed, journal, meditate
- **Logging:** Single "Mark complete" button
- **Completion:** One entry with value `1.0` marks the task done
- **Target:** None (inherently binary)

## Count

**Use case:** Iterative accumulation toward a numeric goal.

- **Examples:** 100 pushups, 128 oz water, 10,000 steps
- **Logging:** Preset chips (+5, +10, +25) and custom numeric input. Multiple entries per day, each adding to the running total.
- **Completion:** Sum of all entries for the day >= target
- **Target:** Required (the number to hit)
- **Unit:** Optional display label ("reps", "oz", "steps")

## Timer

**Use case:** Time spent toward a daily goal.

- **Examples:** Read 30 min, practice piano 20 min, walk 45 min
- **Logging:** Preset chips (+5m, +10m, +15m) and custom input. Log sessions throughout the day.
- **Completion:** Sum of all entries >= target minutes
- **Target:** Required (minutes)
- **Unit:** Defaults to "min"

## Numeric

**Use case:** Daily readings where any entry counts as completion. No target threshold — the value itself is the data.

- **Examples:** Body weight, mood (1-10), blood pressure, hours slept
- **Logging:** Single numeric input field
- **Completion:** Any entry logged = done (the goal is consistency of measurement, not hitting a number)
- **Target:** None
- **Unit:** Optional ("kg", "lbs", "hrs")

## Yes/No

**Use case:** Reflective daily questions where you want to track the answer over time.

- **Examples:** "Did you stretch?", "Did you eat clean?", "Were you kind today?"
- **Logging:** Two-button choice (Yes / No)
- **Completion:** Either answer marks the task done (the point is answering honestly, not always saying yes)
- **Values:** Yes = `1.0`, No = `0.0`

---

## Shared Behavior

All task types share these properties:

- **Schedule:** Which days of the week (default: every day) and what time(s)
- **Overdue:** If the scheduled time passes without completion, the task enters overdue state (still completable until midnight)
- **Day boundary:** Midnight local time. A task logged at 11:59 PM counts for today; 12:01 AM counts for tomorrow.
- **Streak impact:** Every scheduled task must be 100% done for the day to be earned. One missed task = streak broken.
