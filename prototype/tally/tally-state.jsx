// Tally — state, storage, clock, completion math.
// Everything that touches data lives here. UI files just consume `useStore()`.

const TALLY_STORAGE_KEY = "tally.store.v2";

// ─── Time helpers ───────────────────────────────────────
// "now" comes from a simulated clock = real-time + offset. Demo controls
// shift the offset so the user can advance hours / days to feel the streak.
function nowMs(store) {
  return Date.now() + (store?.clockOffset || 0);
}
function nowDate(store) {
  return new Date(nowMs(store));
}
function pad2(n) { return String(n).padStart(2, "0"); }
function dateKey(d) { return `${d.getFullYear()}-${pad2(d.getMonth()+1)}-${pad2(d.getDate())}`; }
function timeKey(d) { return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`; }
function parseHHMM(s) { const [h,m] = s.split(":").map(Number); return { h, m, mins: h*60+m }; }
function dayOfWeek(d) { return (d.getDay() + 6) % 7; } // 0 = Mon
const DAY_LABELS = ["M","T","W","T","F","S","S"];
const DAY_NAMES  = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];
const MONTH_NAMES_SHORT = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

function addDays(date, n) { const d = new Date(date); d.setDate(d.getDate() + n); d.setHours(0,0,0,0); return d; }
function startOfDay(d) { const x = new Date(d); x.setHours(0,0,0,0); return x; }

// ─── Sample task data + seed log ────────────────────────
// Tasks are pre-seeded so the prototype feels populated on first run.
// Schedule fields:
//   days: array of 0..6 (Mon..Sun) — empty array means daily
//   times: array of "HH:MM" or single "all-day"

function uid() { return Math.random().toString(36).slice(2, 10); }

const SEED_TASKS = [
  { id: "t-vit",     name: "Vitamins",      type: "check",   target: null, unit: null,  days: [0,1,2,3,4,5,6], times: ["07:30"] },
  { id: "t-weigh",   name: "Weigh-in",      type: "numeric", target: null, unit: "kg",  days: [0,1,2,3,4,5,6], times: ["07:30"] },
  { id: "t-stretch", name: "Stretch",       type: "yesno",   target: null, unit: null,  days: [0,1,2,3,4,5,6], times: ["08:00"] },
  { id: "t-push",    name: "Push-ups",      type: "count",   target: 100,  unit: "reps",days: [0,1,2,3,4,5,6], times: ["08:00","12:00","18:00"] },
  { id: "t-water",   name: "Water",         type: "count",   target: 128,  unit: "oz",  days: [0,1,2,3,4,5,6], times: ["all-day"] },
  { id: "t-walk",    name: "Lunch walk",    type: "timer",   target: 30,   unit: "min", days: [0,1,2,3,4],     times: ["12:30"] },
  { id: "t-squat",   name: "Squats",        type: "count",   target: 50,   unit: "reps",days: [0,2,4],         times: ["18:00"] },
  { id: "t-read",    name: "Read",          type: "timer",   target: 20,   unit: "min", days: [0,1,2,3,4,5,6], times: ["21:00"] },
];

// Build seed log — 30 days of history. Every day hits 100% except:
//   offset 16: full miss day (pushups + squats skipped)
//   offset 22, 9: partial days (one task short)
// All count/timer totals sum EXACTLY to target so streak math is clean.
function buildSeedLog() {
  const log = [];
  const today = startOfDay(new Date());
  for (let offset = 30; offset >= 1; offset--) {
    const d = addDays(today, -offset);
    const key = dateKey(d);
    const dow = dayOfWeek(d);
    const missDay = offset === 16;
    const partialPush = offset === 22;
    const partialRead = offset === 9;

    SEED_TASKS.forEach(t => {
      if (t.days.length && !t.days.includes(dow)) return;
      if (missDay && (t.id === "t-push" || t.id === "t-squat")) return;

      if (t.type === "check" || t.type === "yesno") {
        log.push({ id: uid(), taskId: t.id, date: key, time: t.times[0] === "all-day" ? "20:00" : t.times[0], value: true, ts: d.getTime() });
      } else if (t.type === "numeric") {
        // gentle downward trend on weigh-in
        const base = 76.5 - (30 - offset) * 0.08;
        log.push({ id: uid(), taskId: t.id, date: key, time: t.times[0], value: Math.round(base * 10) / 10, ts: d.getTime() });
      } else if (t.type === "count") {
        if (partialPush && t.id === "t-push") {
          // only 60 of 100 reps logged
          log.push({ id: uid(), taskId: t.id, date: key, time: "08:14", value: 30, ts: d.getTime() });
          log.push({ id: uid(), taskId: t.id, date: key, time: "12:08", value: 30, ts: d.getTime() });
        } else {
          // Split into sets that sum EXACTLY to target
          const sets = t.id === "t-water" ? 8 : 3;
          const each = Math.floor(t.target / sets);
          const remainder = t.target - each * sets;
          for (let i = 0; i < sets; i++) {
            const v = each + (i < remainder ? 1 : 0);
            const baseH = t.id === "t-water" ? 7 : 8;
            log.push({ id: uid(), taskId: t.id, date: key, time: pad2(baseH + i*2)+":"+pad2(10 + i*5), value: v, ts: d.getTime() });
          }
        }
      } else if (t.type === "timer") {
        if (partialRead && t.id === "t-read") {
          log.push({ id: uid(), taskId: t.id, date: key, time: t.times[0], value: 12, ts: d.getTime() });
        } else {
          log.push({ id: uid(), taskId: t.id, date: key, time: t.times[0], value: t.target, ts: d.getTime() });
        }
      }
    });
  }

  // Today's partial log — depends on real-time but seed reasonably so
  // the prototype always looks "in progress"
  const todayKey = dateKey(today);
  log.push({ id: uid(), taskId: "t-vit",     date: todayKey, time: "07:34", value: true,    ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-weigh",   date: todayKey, time: "07:38", value: 74.2,    ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-stretch", date: todayKey, time: "08:02", value: true,    ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-push",    date: todayKey, time: "08:14", value: 20,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-push",    date: todayKey, time: "12:08", value: 25,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-push",    date: todayKey, time: "13:45", value: 20,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-water",   date: todayKey, time: "07:10", value: 16,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-water",   date: todayKey, time: "08:30", value: 16,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-water",   date: todayKey, time: "10:00", value: 16,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-water",   date: todayKey, time: "11:15", value: 16,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-water",   date: todayKey, time: "12:45", value: 8,       ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-water",   date: todayKey, time: "13:30", value: 16,      ts: today.getTime() });
  log.push({ id: uid(), taskId: "t-walk",    date: todayKey, time: "12:55", value: 32,      ts: today.getTime() });
  return log;
}

const SEED_STORE = () => ({
  tasks: SEED_TASKS.map(t => ({ ...t, archived: false, createdAt: Date.now() })),
  log: buildSeedLog(),
  clockOffset: 0,
  settings: { dark: false, density: "regular", icons: true },
  onboarded: true,
});

// ─── Storage ───────────────────────────────────────────
function loadStore() {
  try {
    const raw = localStorage.getItem(TALLY_STORAGE_KEY);
    if (!raw) return SEED_STORE();
    const parsed = JSON.parse(raw);
    // Patch missing fields
    if (!parsed.settings) parsed.settings = { dark: false, density: "regular", icons: true };
    if (parsed.clockOffset == null) parsed.clockOffset = 0;
    if (parsed.onboarded == null) parsed.onboarded = true;
    return parsed;
  } catch (e) {
    return SEED_STORE();
  }
}
function saveStore(store) {
  try { localStorage.setItem(TALLY_STORAGE_KEY, JSON.stringify(store)); } catch (e) {}
}

// ─── Reducer ───────────────────────────────────────────
function tallyReducer(state, action) {
  switch (action.type) {
    case "set":         return { ...state, ...action.patch };
    case "settings":    return { ...state, settings: { ...state.settings, ...action.patch } };
    case "addTask":     return { ...state, tasks: [...state.tasks, { id: uid(), archived: false, createdAt: Date.now(), ...action.task }] };
    case "editTask":    return { ...state, tasks: state.tasks.map(t => t.id === action.id ? { ...t, ...action.patch } : t) };
    case "removeTask":  return { ...state, tasks: state.tasks.filter(t => t.id !== action.id), log: state.log.filter(l => l.taskId !== action.id) };
    case "archiveTask": return { ...state, tasks: state.tasks.map(t => t.id === action.id ? { ...t, archived: !t.archived } : t) };
    case "addLog":      return { ...state, log: [...state.log, { id: uid(), ts: Date.now(), ...action.entry }] };
    case "removeLog":   return { ...state, log: state.log.filter(l => l.id !== action.id) };
    case "advanceClock":return { ...state, clockOffset: state.clockOffset + action.deltaMs };
    case "resetClock":  return { ...state, clockOffset: 0 };
    case "reset":       return SEED_STORE();
    default: return state;
  }
}

// ─── Hook + context ───────────────────────────────────
const TallyCtx = React.createContext(null);

function useTallyStore() {
  return React.useContext(TallyCtx);
}

function TallyProvider({ children }) {
  const [store, dispatch] = React.useReducer(tallyReducer, null, () => loadStore());
  React.useEffect(() => { saveStore(store); }, [store]);

  // Recompute "now" every minute so the time-rail / status pips don't go stale
  const [, tick] = React.useReducer(x => x + 1, 0);
  React.useEffect(() => {
    const id = setInterval(tick, 60000);
    return () => clearInterval(id);
  }, []);

  const api = React.useMemo(() => ({
    store,
    dispatch,
    now: () => nowDate(store),
    todayKey: () => dateKey(nowDate(store)),
  }), [store]);

  return <TallyCtx.Provider value={api}>{children}</TallyCtx.Provider>;
}

// ─── Derived selectors ────────────────────────────────
// taskState — given a task + a date + the full log, returns:
//   { status: 'done'|'partial'|'overdue'|'due'|'off',
//     pct, sum, label, count }
function taskStateFor(task, date, log, now) {
  const key = dateKey(date);
  const dow = dayOfWeek(date);
  const scheduled = task.days.length === 0 || task.days.includes(dow);
  if (!scheduled) return { status: "off", pct: 0, label: "Not scheduled" };

  const entries = log.filter(l => l.taskId === task.id && l.date === key);
  const isPastDate = startOfDay(date).getTime() < startOfDay(now).getTime();
  const isFutureDate = startOfDay(date).getTime() > startOfDay(now).getTime();
  // Used to decide if a non-all-day task is overdue
  const firstTime = task.times[0];
  const nowMins = now.getHours() * 60 + now.getMinutes();
  const dueTime = firstTime === "all-day" ? 23*60+59 : parseHHMM(firstTime).mins;
  const isToday = key === dateKey(now);
  const passedTime = isToday ? nowMins > dueTime : isPastDate;

  switch (task.type) {
    case "check":
    case "yesno": {
      const done = entries.some(e => e.value === true || e.value === "yes");
      if (done) return { status: "done", pct: 1, label: task.type === "yesno" ? "Yes" : "Done", count: 1 };
      return { status: passedTime ? (isFutureDate ? "due" : "overdue") : "due", pct: 0, label: "—" };
    }
    case "numeric": {
      const e = entries[entries.length - 1];
      if (e) return { status: "done", pct: 1, label: `${typeof e.value === "number" ? Number(e.value).toFixed(1) : e.value}${task.unit ? " " + task.unit : ""}`, count: 1, value: e.value };
      return { status: passedTime ? (isFutureDate ? "due" : "overdue") : "due", pct: 0, label: "—" };
    }
    case "count": {
      const sum = entries.reduce((a, e) => a + (Number(e.value) || 0), 0);
      const pct = Math.min(sum / task.target, 1);
      const done = sum >= task.target;
      return {
        status: done ? "done" : sum > 0 ? "partial" : (passedTime && !isFutureDate ? "overdue" : "due"),
        pct, sum,
        label: `${Math.round(sum)} / ${task.target} ${task.unit || ""}`.trim(),
        count: entries.length,
      };
    }
    case "timer": {
      const sum = entries.reduce((a, e) => a + (Number(e.value) || 0), 0);
      const pct = Math.min(sum / task.target, 1);
      const done = sum >= task.target;
      return {
        status: done ? "done" : sum > 0 ? "partial" : (passedTime && !isFutureDate ? "overdue" : "due"),
        pct, sum,
        label: `${Math.round(sum)} / ${task.target} ${task.unit || "min"}`.trim(),
        count: entries.length,
      };
    }
    default: return { status: "due", pct: 0, label: "—" };
  }
}

// Day completion — pct + counts for tasks scheduled on a given date.
function dayCompletionFor(date, tasks, log, now) {
  const dow = dayOfWeek(date);
  const scheduled = tasks.filter(t => !t.archived && (t.days.length === 0 || t.days.includes(dow)));
  if (scheduled.length === 0) return { done: 0, partial: 0, overdue: 0, total: 0, pct: 0 };
  const states = scheduled.map(t => taskStateFor(t, date, log, now));
  const done = states.filter(s => s.status === "done").length;
  const partial = states.filter(s => s.status === "partial").length;
  const overdue = states.filter(s => s.status === "overdue").length;
  return { done, partial, overdue, total: scheduled.length, pct: done / scheduled.length };
}

// Streak — count back from yesterday of consecutive days that hit 100%.
// Also include today if 100%. Returns { current, best, history }.
function streakFor(tasks, log, now) {
  const history = [];
  // Look back 60 days for history
  for (let i = 60; i >= 0; i--) {
    const d = addDays(now, -i);
    const day = dayCompletionFor(d, tasks, log, now);
    history.push({ date: dateKey(d), pct: day.pct, done: day.done, total: day.total, isToday: i === 0 });
  }
  // Current streak — walk back from yesterday until <100% day. Include today if 100%.
  let current = 0;
  const todayItem = history[history.length - 1];
  if (todayItem.pct >= 1) current = 1;
  for (let i = history.length - 2; i >= 0; i--) {
    if (history[i].pct >= 1) current++;
    else break;
  }
  // Best — longest run anywhere in history
  let best = 0, run = 0;
  history.forEach(h => { if (h.pct >= 1) { run++; best = Math.max(best, run); } else run = 0; });
  return { current, best, history };
}

// 14-day sparkline data for a single task (% completion each day)
function taskHistoryFor(task, log, now, days = 14) {
  const out = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = addDays(now, -i);
    out.push(taskStateFor(task, d, log, now).pct);
  }
  return out;
}

// Group tasks by time-block for the Today screen
function groupByTimeBlock(tasks, date) {
  const dow = dayOfWeek(date);
  const scheduled = tasks.filter(t => !t.archived && (t.days.length === 0 || t.days.includes(dow)));
  const morning = [], afternoon = [], evening = [], allday = [];
  scheduled.forEach(t => {
    const ft = t.times[0];
    if (ft === "all-day") allday.push(t);
    else {
      const h = parseInt(ft);
      if (h < 12) morning.push(t);
      else if (h < 18) afternoon.push(t);
      else evening.push(t);
    }
  });
  // sort by first time
  const byTime = (a, b) => parseHHMM(a.times[0]).mins - parseHHMM(b.times[0]).mins;
  morning.sort(byTime); afternoon.sort(byTime); evening.sort(byTime);
  return { morning, afternoon, evening, allday };
}

function describeSchedule(task) {
  const days = task.days.length === 0 || task.days.length === 7 ? "Daily" :
               task.days.length === 5 && task.days.slice().sort().join() === "0,1,2,3,4" ? "Weekdays" :
               task.days.length === 2 && task.days.includes(5) && task.days.includes(6) ? "Weekends" :
               task.days.map(d => DAY_NAMES[d]).join(" · ");
  const times = task.times.length > 2 ? `${task.times.length} times/day` : task.times.join(" · ");
  return { days, times };
}

function defaultLogValue(task) {
  switch (task.type) {
    case "count":
      // sensible default — quarter of target
      return Math.round(task.target / 4);
    case "timer":
      return task.target;
    case "numeric":
      return 0;
    default:
      return true;
  }
}

Object.assign(window, {
  TallyCtx, useTallyStore, TallyProvider,
  dateKey, timeKey, nowDate, addDays, startOfDay, dayOfWeek, parseHHMM,
  taskStateFor, dayCompletionFor, streakFor, taskHistoryFor,
  groupByTimeBlock, describeSchedule, defaultLogValue,
  DAY_LABELS, DAY_NAMES, MONTH_NAMES_SHORT,
  uid, pad2,
});
