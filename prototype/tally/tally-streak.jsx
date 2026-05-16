// Tally — Streak screen + Month calendar with day detail.

function StreakScreen() {
  const { store, now } = useTallyStore();
  const { push } = useNav();
  const c = tallyColors(store.settings.dark);
  const today = now();
  const streak = streakFor(store.tasks, store.log, today);

  // Month view: which month
  const [monthOffset, setMonthOffset] = React.useState(0);
  const viewMonth = (() => {
    const d = new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
    return d;
  })();
  const monthLabel = `${["January","February","March","April","May","June","July","August","September","October","November","December"][viewMonth.getMonth()]} ${viewMonth.getFullYear()}`;

  // Build month grid
  const firstDow = (viewMonth.getDay() + 6) % 7; // Mon = 0
  const daysInMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < firstDow; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) {
    const date = new Date(viewMonth.getFullYear(), viewMonth.getMonth(), d);
    const day = dayCompletionFor(date, store.tasks, store.log, today);
    const isToday = dateKey(date) === dateKey(today);
    const isFuture = startOfDay(date).getTime() > startOfDay(today).getTime();
    cells.push({ date, day, isToday, isFuture });
  }
  while (cells.length % 7 !== 0) cells.push(null);

  // Month aggregate
  const monthCells = cells.filter(c => c && !c.isFuture);
  const monthEarned = monthCells.filter(c => c.day.pct >= 1).length;
  const monthRate = monthCells.length > 0 ? Math.round(monthEarned / monthCells.length * 100) : 0;

  return (
    <Screen>
      <Header kicker="STREAK · HISTORY" title="Streak"/>

      {/* Hero */}
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span style={tLbl(c.dim)}>CURRENT</span>
          <span style={{ ...tMono(11), color: c.dim }}>
            {streak.current > 0 ? `SINCE ${streakStartLabel(streak)}` : "WAITING TO START"}
          </span>
        </div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 8, marginTop: 6 }}>
          <span style={{ ...tH(80, 500), color: streak.current > 0 ? c.accent : c.dim }}>{streak.current}</span>
          <span style={{ ...tH(22, 500), color: c.dim }}>day{streak.current === 1 ? "" : "s"}</span>
          <span style={{ marginLeft: "auto", ...tMono(10), color: streak.current >= streak.best && streak.current > 0 ? c.pos : c.dim }}>
            {streak.current >= streak.best && streak.current > 0 ? "↑ ALL-TIME BEST" : `BEST · ${streak.best}d`}
          </span>
        </div>

        {/* 30-day strip */}
        <div style={{ display: "flex", gap: 2, marginTop: 14, height: 36 }}>
          {streak.history.slice(-30).map((d, i, arr) => (
            <button key={d.date} onClick={() => push({ kind: "dayDetail", date: d.date })} style={{
              flex: 1, background: d.pct >= 1 ? c.accent : d.pct >= 0.5 ? c.accentSoft : c.dim3,
              borderRadius: 1, position: "relative", border: "none", padding: 0,
              outline: d.isToday ? `1px solid ${c.accent}` : "none", outlineOffset: 1, cursor: "pointer" }}/>
          ))}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6, ...tMono(10), color: c.dim }}>
          <span>30 DAYS AGO</span><span>TODAY</span>
        </div>
      </Card>

      {/* Stats */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
        <StatTile c={c} label="BEST"  value={`${streak.best}d`} />
        <StatTile c={c} label="EARNED 60D" value={`${streak.history.filter(d => d.pct >= 1).length}`} />
        <StatTile c={c} label="AVG"   value={`${Math.round(streak.history.reduce((a, d) => a + d.pct, 0) / streak.history.length * 100)}%`} />
      </div>

      {/* Month calendar with paging */}
      <div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
          <button onClick={() => setMonthOffset(o => o - 1)} style={{ ...tMono(11, 600), color: c.dim, padding: "4px 8px", background: "transparent", letterSpacing: ".1em" }}>‹ PREV</button>
          <div style={{ ...tH(15, 500) }}>{monthLabel}</div>
          <button onClick={() => setMonthOffset(o => Math.min(0, o + 1))} disabled={monthOffset === 0}
            style={{ ...tMono(11, 600), color: monthOffset === 0 ? c.dim2 : c.dim, padding: "4px 8px", background: "transparent", letterSpacing: ".1em" }}>NEXT ›</button>
        </div>
        <div style={{ ...tMono(10), color: c.dim, marginBottom: 6, textAlign: "center", letterSpacing: ".1em" }}>
          {monthEarned} EARNED · {monthRate}% RATE
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 4 }}>
          {DAY_LABELS.map((d, i) => <div key={i} style={{ ...tMono(9), color: c.dim, textAlign: "center", padding: "4px 0" }}>{d}</div>)}
          {cells.map((cell, i) => {
            if (!cell) return <div key={`pad${i}`} />;
            const { date, day, isToday, isFuture } = cell;
            const earned = day.pct >= 1;
            const partial = day.pct > 0 && day.pct < 1;
            return (
              <button key={i}
                onClick={() => !isFuture && push({ kind: "dayDetail", date: dateKey(date) })}
                disabled={isFuture}
                style={{ aspectRatio: "1", borderRadius: 6,
                  background: isFuture ? "transparent" : earned ? c.accent : partial ? c.accentSoft : c.bg3,
                  outline: isToday ? `1.5px solid ${c.text}` : "none", outlineOffset: -1,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  ...tMono(11, 600), color: earned ? "#fff" : isFuture ? c.dim2 : c.dim,
                  border: "none", cursor: isFuture ? "default" : "pointer",
                }}>
                {date.getDate()}
              </button>
            );
          })}
        </div>
      </div>

      <div style={{ textAlign: "center", padding: "8px 0 4px", ...tMono(10), color: c.dim, letterSpacing: ".14em" }}>
        TAP A DAY TO REVIEW
      </div>
    </Screen>
  );
}

function streakStartLabel(streak) {
  if (streak.current === 0) return "—";
  // The day at history[length - current - 1] was the last broken day
  const firstDayIdx = streak.history.length - streak.current;
  const d = streak.history[firstDayIdx];
  if (!d) return "—";
  const date = new Date(d.date + "T00:00:00");
  return `${MONTH_NAMES_SHORT[date.getMonth()].toUpperCase()} ${date.getDate()}`;
}

// ─── Day detail (review a past day) ────────────────
function DayDetail({ date, onBack }) {
  const { store, now } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const dateObj = new Date(date + "T00:00:00");
  const today = now();
  const dow = dayOfWeek(dateObj);
  const scheduled = store.tasks.filter(t => !t.archived && (t.days.length === 0 || t.days.includes(dow)));
  const day = dayCompletionFor(dateObj, store.tasks, store.log, today);
  const dayLog = store.log.filter(l => l.date === date);

  return (
    <StackScreen
      title={`${DAY_NAMES[dow]} · ${MONTH_NAMES_SHORT[dateObj.getMonth()]} ${dateObj.getDate()}`}
      onBack={onBack}
    >
      <div>
        <div style={tLbl(c.dim)}>DAY REVIEW</div>
        <h1 style={{ ...tH(32, 500), margin: "4px 0 0" }}>
          {day.pct >= 1 ? <span style={{ color: c.pos }}>Day earned ✓</span> :
           day.total === 0 ? "Rest day" :
           <span>{day.done} of {day.total} · <span style={{ color: c.neg }}>missed</span></span>}
        </h1>
        <div style={{ ...tMono(11), color: c.dim, marginTop: 6 }}>
          {Math.round(day.pct * 100)}% COMPLETION · {day.done} DONE · {day.partial} PARTIAL · {day.overdue} OVERDUE
        </div>
      </div>

      {scheduled.length > 0 && (
        <div>
          <div style={tLbl(c.dim)}>TASKS · {scheduled.length}</div>
          {scheduled.map(t => {
            const s = taskStateFor(t, dateObj, store.log, today);
            return (
              <div key={t.id} style={{ display: "grid", gridTemplateColumns: "auto 1fr auto", gap: 10, padding: "12px 0", borderBottom: `1px solid ${c.rule}`, alignItems: "center" }}>
                <StatusPip status={s.status}/>
                <div>
                  <div style={{ ...tH(14, 500) }}>{t.name}</div>
                  <div style={{ ...tMono(10), color: c.dim, marginTop: 2 }}>
                    {t.times.join(" · ").toUpperCase()} · {s.label.toUpperCase()}
                  </div>
                </div>
                <span style={{ ...tMono(11, 600), color: s.status === "done" ? c.pos : s.status === "overdue" ? c.neg : c.text }}>
                  {Math.round(s.pct * 100)}%
                </span>
              </div>
            );
          })}
        </div>
      )}

      {dayLog.length > 0 && (
        <div>
          <div style={tLbl(c.dim)}>{dayLog.length} ENTRIES</div>
          {dayLog.sort((a, b) => a.time.localeCompare(b.time)).map(e => {
            const t = store.tasks.find(x => x.id === e.taskId);
            return (
              <div key={e.id} style={{ display: "grid", gridTemplateColumns: "auto 1fr auto", gap: 10, padding: "10px 0", borderBottom: `1px solid ${c.rule}`, alignItems: "baseline" }}>
                <span style={{ ...tMono(11), color: c.dim }}>{e.time}</span>
                <span style={{ ...tBody(13, 500) }}>{t?.name || "—"}</span>
                <span style={{ ...tMono(13, 600), color: c.text }}>
                  {e.value === true ? "✓" : e.value === false ? "✗" : typeof e.value === "number" ? (Number.isInteger(e.value) ? `+${e.value}` : Number(e.value).toFixed(1)) : String(e.value)}
                  {t?.unit ? ` ${t.unit}` : ""}
                </span>
              </div>
            );
          })}
        </div>
      )}
    </StackScreen>
  );
}

Object.assign(window, { StreakScreen, DayDetail });
