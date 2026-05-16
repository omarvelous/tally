// Tally — Today + Task detail screens.

// ─── Task row (used on Today and All Tasks) ─────────
function TaskRow({ task, state, history, onClick }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const compact = store.settings.density === "compact";
  const sched = describeSchedule(task);
  return (
    <button onClick={onClick} style={{
      width: "100%", display: "grid",
      gridTemplateColumns: "auto 1fr auto auto",
      gap: 10, padding: compact ? "10px 0" : "13px 0",
      borderBottom: `1px solid ${c.rule}`,
      alignItems: "center", background: "transparent", textAlign: "left",
    }}>
      <StatusPip status={state.status} />
      <div style={{ minWidth: 0 }}>
        <div style={{ ...tH(14, 500), color: c.text, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{task.name}</div>
        <div style={{ display: "flex", gap: 8, marginTop: 3, alignItems: "center" }}>
          <span style={{ ...tMono(10), color: c.dim }}>
            {task.times[0] === "all-day" ? "ALL DAY" : task.times[0]}
            {task.times.length > 1 ? ` +${task.times.length - 1}` : ""}
          </span>
          {state.label && state.label !== "—" && state.label !== "Not scheduled" && (
            <span style={{ ...tMono(10), color: state.status === "done" ? c.pos : state.status === "overdue" ? c.neg : c.dim }}>
              {state.label.toUpperCase()}
            </span>
          )}
        </div>
      </div>
      {history && history.length > 1 && <Spark values={history} w={48} h={16}/>}
      <div style={{ ...tMono(11, 600),
        color: state.status === "done" ? c.pos : state.status === "overdue" ? c.neg : c.text,
        minWidth: 36, textAlign: "right" }}>
        {state.pct === 0 && state.status !== "done" ? "—" : `${Math.round(state.pct * 100)}%`}
      </div>
    </button>
  );
}

// ─── TodayScreen ───────────────────────────────────
function TodayScreen() {
  const { store, dispatch, now } = useTallyStore();
  const { push, setTab, popAll } = useNav();
  const c = tallyColors(store.settings.dark);
  const today = now();
  const todayKey = dateKey(today);
  const day = dayCompletionFor(today, store.tasks, store.log, today);
  const { morning, afternoon, evening, allday } = groupByTimeBlock(store.tasks, today);
  const streak = streakFor(store.tasks, store.log, today);

  const scheduledToday = [...morning, ...afternoon, ...evening, ...allday];
  if (scheduledToday.length === 0) {
    return (
      <Screen>
        <Header kicker={`${DAY_NAMES[dayOfWeek(today)].toUpperCase()} · ${MONTH_NAMES_SHORT[today.getMonth()].toUpperCase()} ${today.getDate()} · ${pad2(today.getHours())}:${pad2(today.getMinutes())}`} title="Today" />
        <Empty title="No tasks scheduled today"
          body="It's a rest day — or add some tasks to fill it in."
          action={<Btn onClick={() => push({ kind: "addTask" })}><TIcon.Plus/> New task</Btn>} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Header
        kicker={`${DAY_NAMES[dayOfWeek(today)].toUpperCase()} · ${MONTH_NAMES_SHORT[today.getMonth()].toUpperCase()} ${today.getDate()} · ${pad2(today.getHours())}:${pad2(today.getMinutes())}`}
        title="Today"
        right={
          <button onClick={() => { setTab(3); popAll(); }} style={{ textAlign: "right", background: "transparent", border: "none", padding: "4px 0 4px 12px" }}>
            <div style={tLbl(c.dim)}>STREAK</div>
            <div style={{ ...tMono(22, 600), color: c.accent, marginTop: 4 }}>{streak.current}d</div>
          </button>
        }
      />

      {/* Day completion */}
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span style={tLbl(c.dim)}>DAY COMPLETION</span>
          <span style={{ ...tMono(11), color: c.dim }}>{day.done}/{day.total} TASKS</span>
        </div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 6, marginTop: 6 }}>
          <span style={{ ...tH(56, 500), color: c.text }}>{Math.round(day.pct * 100)}</span>
          <span style={{ ...tH(20, 500), color: c.dim }}>%</span>
          <span style={{ marginLeft: "auto", ...tMono(10), color: day.pct >= 1 ? c.pos : c.dim, textAlign: "right" }}>
            {day.pct >= 1 ? "DAY EARNED ✓" : "NEED 100% TO EARN"}
          </span>
        </div>
        {/* Segmented bar — each task = a tile */}
        <div style={{ display: "flex", gap: 2, marginTop: 12, height: 6 }}>
          {scheduledToday.map(t => {
            const s = taskStateFor(t, today, store.log, today);
            return <div key={t.id} style={{ flex: 1,
              background: s.status === "done" ? c.pos : s.status === "partial" ? c.accentSoft : s.status === "overdue" ? c.neg : c.dim3,
              borderRadius: 1 }} />;
          })}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8, ...tMono(10), color: c.dim }}>
          <span>{day.done} done</span>
          {day.partial > 0 && <span style={{ color: c.accent }}>{day.partial} in progress</span>}
          {day.overdue > 0 && <span style={{ color: c.neg }}>{day.overdue} overdue</span>}
        </div>
      </Card>

      {/* Time blocks */}
      {[
        ["MORNING · 06–12", morning],
        ["AFTERNOON · 12–18", afternoon],
        ["EVENING · 18+",  evening],
        ["ALL DAY",       allday],
      ].map(([label, list]) => list.length === 0 ? null : (
        <div key={label}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 4 }}>
            <span style={tLbl(c.dim)}>{label}</span>
            <span style={{ ...tMono(10), color: c.dim }}>
              {list.filter(t => taskStateFor(t, today, store.log, today).status === "done").length}/{list.length}
            </span>
          </div>
          {list.map(t => {
            const s = taskStateFor(t, today, store.log, today);
            const hist = taskHistoryFor(t, store.log, today, 14);
            return <TaskRow key={t.id} task={t} state={s} history={hist}
              onClick={() => push({ kind: "taskDetail", taskId: t.id })} />;
          })}
        </div>
      ))}
    </Screen>
  );
}

// ─── TaskDetail / iterative log ────────────────────
function TaskDetail({ taskId, onBack }) {
  const { store, dispatch, now } = useTallyStore();
  const { push } = useNav();
  const c = tallyColors(store.settings.dark);
  const task = store.tasks.find(t => t.id === taskId);
  if (!task) return <StackScreen title="Task not found" onBack={onBack} />;
  const today = now();
  const tKey = dateKey(today);
  const state = taskStateFor(task, today, store.log, today);
  const todayEntries = store.log.filter(l => l.taskId === taskId && l.date === tKey).sort((a, b) => a.time.localeCompare(b.time));
  const sched = describeSchedule(task);

  function logValue(value) {
    dispatch({ type: "addLog", entry: { taskId, date: tKey, time: timeKey(today), value } });
  }
  function undoEntry(id) { dispatch({ type: "removeLog", id }); }

  return (
    <StackScreen
      title={task.name}
      onBack={onBack}
      right={<button onClick={() => push({ kind: "editTask", taskId })} style={{ ...tMono(11), color: c.dim, background: "transparent" }}>EDIT</button>}
    >
      <div>
        <div style={tLbl(c.dim)}>{sched.times.toUpperCase()} · {sched.days.toUpperCase()}</div>
        <h1 style={{ ...tH(28, 500), margin: "4px 0 0" }}>{task.name}</h1>
      </div>

      <TaskLogUI task={task} state={state} c={c} onLog={logValue} />

      {/* Today's log */}
      {todayEntries.length > 0 && (
        <div>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
            <span style={tLbl(c.dim)}>TODAY · {todayEntries.length} {task.type === "count" ? "SETS" : "ENTR" + (todayEntries.length === 1 ? "Y" : "IES")}</span>
            <span style={{ ...tMono(10), color: c.dim }}>TAP TO UNDO</span>
          </div>
          {todayEntries.map((e, i) => (
            <button key={e.id} onClick={() => undoEntry(e.id)} style={{ width: "100%",
              display: "grid", gridTemplateColumns: "30px 1fr auto auto", padding: "10px 0",
              borderBottom: `1px solid ${c.rule}`, alignItems: "center", gap: 8,
              background: "transparent", textAlign: "left" }}>
              <span style={{ ...tMono(11), color: c.dim }}>{String(i+1).padStart(2,"0")}</span>
              <span style={{ ...tMono(11), color: c.dim }}>{e.time}</span>
              <span style={{ ...tMono(14, 600), color: c.text }}>
                {task.type === "check" || task.type === "yesno" ? "✓" :
                 task.type === "numeric" ? `${typeof e.value === "number" ? Number(e.value).toFixed(1) : e.value}` :
                 `+${e.value}`}
              </span>
              <span style={{ ...tMono(10), color: c.dim }}>{task.unit ? task.unit.toUpperCase() : ""}</span>
            </button>
          ))}
          {(task.type === "count" || task.type === "timer") && (
            <div style={{ display: "grid", gridTemplateColumns: "30px 1fr auto auto", padding: "12px 0", alignItems: "center", gap: 8 }}>
              <span style={{ ...tMono(11, 600) }}>Σ</span>
              <span style={{ ...tMono(11), color: c.dim }}>TOTAL</span>
              <span style={{ ...tMono(15, 600), color: state.status === "done" ? c.pos : c.accent }}>{Math.round(state.sum)}</span>
              <span style={{ ...tMono(10), color: c.dim }}>{task.unit?.toUpperCase()}</span>
            </div>
          )}
        </div>
      )}

      {/* Trend */}
      <div>
        <div style={tLbl(c.dim)}>LAST 14 DAYS</div>
        <TaskMiniTrend task={task} c={c} now={today} log={store.log} />
        <button onClick={() => push({ kind: "taskStats", taskId })} style={{
          width: "100%", marginTop: 12, padding: "12px 0", background: "transparent",
          border: `1px solid ${c.rule}`, borderRadius: 10, ...tMono(11, 500), color: c.dim, letterSpacing: ".14em" }}>
          VIEW FULL STATS →
        </button>
      </div>
    </StackScreen>
  );
}

// ─── TaskLogUI — type-specific quick-log controls ──
function TaskLogUI({ task, state, c, onLog }) {
  // Big progress hero
  function renderHero() {
    if (task.type === "count" || task.type === "timer") {
      const sum = state.sum || 0;
      const target = task.target;
      return (
        <Card>
          <div style={tLbl(c.dim)}>{task.type === "timer" ? "MINUTES TODAY" : "LOGGED TODAY"}</div>
          <div style={{ display: "flex", alignItems: "baseline", justifyContent: "center", gap: 8, marginTop: 12 }}>
            <span style={{ ...tH(72, 500), color: state.status === "done" ? c.pos : c.text }}>{Math.round(sum)}</span>
            <span style={{ ...tH(24, 500), color: c.dim }}>/ {target}</span>
          </div>
          <div style={{ ...tMono(11), color: c.dim, marginTop: 4, textAlign: "center" }}>
            {(task.unit || "").toUpperCase()} · {Math.round(state.pct * 100)}% COMPLETE
          </div>
          <Bar pct={state.pct} height={8} color={state.status === "done" ? c.pos : c.accent} style={{ marginTop: 14 }} />
        </Card>
      );
    }
    if (task.type === "check") {
      return (
        <Card>
          <div style={tLbl(c.dim)}>STATUS</div>
          <div style={{ ...tH(40, 500), marginTop: 8, color: state.status === "done" ? c.pos : c.text }}>
            {state.status === "done" ? "Done ✓" : state.status === "overdue" ? "Overdue" : "Pending"}
          </div>
        </Card>
      );
    }
    if (task.type === "yesno") {
      return (
        <Card>
          <div style={tLbl(c.dim)}>TODAY'S ANSWER</div>
          <div style={{ ...tH(40, 500), marginTop: 8, color: state.status === "done" ? c.pos : c.text }}>
            {state.label === "—" ? "—" : state.label}
          </div>
        </Card>
      );
    }
    if (task.type === "numeric") {
      return (
        <Card>
          <div style={tLbl(c.dim)}>LATEST READING</div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 6, marginTop: 10 }}>
            <span style={{ ...tH(56, 500), color: state.status === "done" ? c.pos : c.text }}>
              {state.value != null ? Number(state.value).toFixed(1) : "—"}
            </span>
            <span style={{ ...tH(20, 500), color: c.dim }}>{task.unit}</span>
          </div>
        </Card>
      );
    }
  }

  function renderControls() {
    if (task.type === "count") {
      const presets = pickPresets(task);
      return (
        <div>
          <div style={{ ...tLbl(c.dim), marginBottom: 8 }}>QUICK LOG · TAP TO ADD</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8 }}>
            {presets.map((v, i) => (
              <button key={i} onClick={() => onLog(v)} style={{
                padding: "16px 0", borderRadius: 10,
                border: `1px solid ${c.rule}`, background: c.bg2, color: c.text,
                ...tMono(15, 600) }}>+{v}</button>
            ))}
          </div>
          <CustomLogInput unit={task.unit} c={c} onLog={onLog} />
        </div>
      );
    }
    if (task.type === "timer") {
      const presets = [5, 10, 15, task.target];
      return (
        <div>
          <div style={{ ...tLbl(c.dim), marginBottom: 8 }}>ADD MINUTES</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8 }}>
            {presets.map((v, i) => (
              <button key={i} onClick={() => onLog(v)} style={{
                padding: "16px 0", borderRadius: 10,
                border: `1px solid ${c.rule}`, background: c.bg2, color: c.text,
                ...tMono(15, 600) }}>+{v}m</button>
            ))}
          </div>
          <CustomLogInput unit="min" c={c} onLog={onLog} />
        </div>
      );
    }
    if (task.type === "check") {
      return (
        <Btn variant={state.status === "done" ? "secondary" : "primary"} full
          onClick={() => state.status === "done" ? null : onLog(true)}>
          {state.status === "done" ? "Already done · tap log to undo" : <><TIcon.Check/> Mark complete</>}
        </Btn>
      );
    }
    if (task.type === "yesno") {
      return (
        <div style={{ display: "flex", gap: 8 }}>
          <Btn full variant={state.label === "Yes" ? "primary" : "secondary"} onClick={() => onLog(true)}>Yes</Btn>
          <Btn full variant={state.label === "No" ? "primary" : "secondary"} onClick={() => onLog(false)}>No</Btn>
        </div>
      );
    }
    if (task.type === "numeric") {
      return <NumericInput unit={task.unit} c={c} onLog={onLog} />;
    }
  }

  return (
    <React.Fragment>
      {renderHero()}
      {renderControls()}
    </React.Fragment>
  );
}

// Choose reasonable preset increments based on the task's unit/target
function pickPresets(task) {
  const t = task.target || 100;
  if (task.unit === "oz") return [8, 16, 24, 32];
  if (task.unit === "ml") return [125, 250, 500, 750];
  if (task.unit === "L")  return [0.25, 0.5, 1, 2];
  if (task.unit === "cal") return [50, 100, 250, 500];
  // Generic — quarters of target
  const q = Math.max(1, Math.round(t / 20) * 5);
  return [q, q*2, q*3, q*4];
}

function CustomLogInput({ unit, c, onLog }) {
  const [val, setVal] = React.useState("");
  return (
    <div style={{ display: "flex", gap: 8, marginTop: 10, alignItems: "center" }}>
      <div style={{ flex: 1, display: "flex", alignItems: "baseline", gap: 8, padding: "10px 14px", border: `1px solid ${c.rule}`, borderRadius: 10, background: c.bg2 }}>
        <input value={val} onChange={e => setVal(e.target.value.replace(/[^0-9.]/g, ""))}
          placeholder="0" inputMode="decimal"
          style={{ flex: 1, background: "transparent", border: "none", outline: "none", ...tMono(18, 600), color: c.text, width: "100%" }} />
        <span style={{ ...tMono(11), color: c.dim }}>{(unit || "").toUpperCase()}</span>
      </div>
      <Btn variant="primary" disabled={!val || Number(val) <= 0} onClick={() => { if (val && Number(val) > 0) { onLog(Number(val)); setVal(""); } }}>
        <TIcon.Plus/> LOG
      </Btn>
    </div>
  );
}

function NumericInput({ unit, c, onLog }) {
  const [val, setVal] = React.useState("");
  return (
    <div>
      <div style={{ ...tLbl(c.dim), marginBottom: 8 }}>ENTER READING</div>
      <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
        <div style={{ flex: 1, display: "flex", alignItems: "baseline", gap: 8, padding: "14px 18px", border: `1px solid ${c.rule}`, borderRadius: 10, background: c.bg2 }}>
          <input value={val} onChange={e => setVal(e.target.value.replace(/[^0-9.]/g, ""))}
            placeholder="0.0" inputMode="decimal"
            style={{ flex: 1, background: "transparent", border: "none", outline: "none", ...tMono(28, 600), color: c.text, width: "100%" }} />
          <span style={{ ...tMono(13), color: c.dim }}>{(unit || "").toUpperCase()}</span>
        </div>
        <Btn variant="primary" disabled={!val} onClick={() => { if (val) { onLog(Number(val)); setVal(""); } }}>
          SAVE
        </Btn>
      </div>
    </div>
  );
}

// Mini 14-day trend mini-chart for inside task detail
function TaskMiniTrend({ task, c, now, log }) {
  const days = [];
  for (let i = 13; i >= 0; i--) {
    const d = addDays(now, -i);
    days.push({ d, state: taskStateFor(task, d, log, now) });
  }
  return (
    <div style={{ display: "flex", gap: 3, height: 50, alignItems: "flex-end", marginTop: 8 }}>
      {days.map(({ d, state }, i) => (
        <div key={i} style={{ flex: 1, position: "relative" }}>
          <div style={{ height: `${Math.max(state.pct, 0.05) * 100}%`, background: state.pct >= 1 ? c.accent : state.pct > 0 ? c.accentSoft : c.dim3, borderRadius: 2 }} />
          {i === 13 && <div style={{ position: "absolute", left: 0, right: 0, top: -14, ...tMono(8, 600), color: c.dim, textAlign: "center" }}>TODAY</div>}
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { TaskRow, TodayScreen, TaskDetail });
