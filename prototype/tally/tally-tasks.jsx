// Tally — Tasks library + Add/Edit + Per-task stats.

// ─── Tasks library ─────────────────────────────────
function TasksScreen() {
  const { store, dispatch, now } = useTallyStore();
  const { push } = useNav();
  const c = tallyColors(store.settings.dark);
  const today = now();
  const tasks = store.tasks.filter(t => !t.archived);

  // Compute 14-day completion rate per task
  const ratedTasks = tasks.map(t => {
    const hist = taskHistoryFor(t, store.log, today, 14);
    const rate = Math.round(hist.reduce((a, b) => a + b, 0) / hist.length * 100);
    return { t, hist, rate };
  });

  const [sort, setSort] = React.useState("rate");
  const sorted = [...ratedTasks].sort((a, b) => {
    if (sort === "rate") return b.rate - a.rate;
    if (sort === "name") return a.t.name.localeCompare(b.t.name);
    return 0;
  });

  return (
    <Screen>
      <Header
        kicker={`LIBRARY · ${tasks.length} ACTIVE`}
        title="Tasks"
        right={
          <Btn variant="primary" style={{ padding: "8px 12px", ...tMono(11, 600), letterSpacing: ".06em" }}
               onClick={() => push({ kind: "addTask" })}>
            <TIcon.Plus/> NEW
          </Btn>
        }
      />

      {/* sort tabs */}
      <div style={{ display: "flex", gap: 4 }}>
        {[["rate","BY RATE"],["name","BY NAME"]].map(([k, lbl]) => (
          <button key={k} onClick={() => setSort(k)} style={{
            padding: "6px 10px", borderRadius: 6, background: sort === k ? c.accentSoft : "transparent",
            color: sort === k ? c.accent : c.dim, ...tMono(10, 600), letterSpacing: ".1em", border: "none" }}>{lbl}</button>
        ))}
      </div>

      {/* column header */}
      <div style={{ display: "grid", gridTemplateColumns: "auto 1fr auto auto", gap: 10, padding: "6px 0", borderBottom: `1px solid ${c.rule}` }}>
        <span style={tLbl(c.dim)}>—</span>
        <span style={tLbl(c.dim)}>NAME · SCHEDULE</span>
        <span style={tLbl(c.dim)}>14D</span>
        <span style={{ ...tLbl(c.dim), minWidth: 36, textAlign: "right" }}>RATE</span>
      </div>

      {sorted.length === 0 ? (
        <Empty title="No tasks yet" body="Add your first task to start tracking."
          action={<Btn variant="primary" onClick={() => push({ kind: "addTask" })}><TIcon.Plus/> Add task</Btn>} />
      ) : sorted.map(({ t, hist, rate }) => (
        <button key={t.id} onClick={() => push({ kind: "taskStats", taskId: t.id })} style={{
          width: "100%", display: "grid", gridTemplateColumns: "auto 1fr auto auto", gap: 10,
          padding: "12px 0", borderBottom: `1px solid ${c.rule}`, alignItems: "center",
          background: "transparent", textAlign: "left",
        }}>
          <div style={{ width: 6, height: 6, borderRadius: "50%",
            background: rate >= 90 ? c.pos : rate >= 70 ? c.accent : c.neg }} />
          <div>
            <div style={{ ...tH(14, 500) }}>{t.name}</div>
            <div style={{ ...tMono(10), color: c.dim, marginTop: 2 }}>
              {describeSchedule(t).days.toUpperCase()} · {describeSchedule(t).times.toUpperCase()} · {t.type.toUpperCase()}{t.target ? ` · ${t.target} ${t.unit}` : ""}
            </div>
          </div>
          <Spark values={hist} w={48} h={16}/>
          <span style={{ ...tMono(11, 600), color: rate >= 90 ? c.pos : rate >= 70 ? c.text : c.neg, minWidth: 36, textAlign: "right" }}>{rate}%</span>
        </button>
      ))}

      <div style={{ textAlign: "center", padding: "12px 0 4px", ...tMono(10), color: c.dim, letterSpacing: ".14em" }}>
        TAP A TASK FOR FULL STATS
      </div>
    </Screen>
  );
}

// ─── Add / Edit task form ──────────────────────────
function TaskForm({ taskId, onBack }) {
  const { store, dispatch } = useTallyStore();
  const isEdit = !!taskId;
  const existing = isEdit ? store.tasks.find(t => t.id === taskId) : null;
  const c = tallyColors(store.settings.dark);

  const [name,   setName]   = React.useState(existing?.name || "");
  const [type,   setType]   = React.useState(existing?.type || "count");
  const [target, setTarget] = React.useState(existing?.target ?? 100);
  const [unit,   setUnit]   = React.useState(existing?.unit || "reps");
  const [days,   setDays]   = React.useState(existing?.days?.length ? existing.days : [0,1,2,3,4,5,6]);
  const [times,  setTimes]  = React.useState(existing?.times || ["08:00"]);

  const validName = name.trim().length > 0;
  const requiresTarget = type === "count" || type === "timer";
  const validTarget = !requiresTarget || (Number(target) > 0);

  function toggleDay(d) {
    setDays(prev => prev.includes(d) ? prev.filter(x => x !== d) : [...prev, d].sort());
  }
  function addTime() {
    if (times.includes("all-day")) return;
    setTimes([...times, "12:00"]);
  }
  function setTimeAt(i, v) {
    setTimes(times.map((t, j) => j === i ? v : t));
  }
  function removeTime(i) { setTimes(times.filter((_, j) => j !== i)); }
  function toggleAllDay() {
    if (times.includes("all-day")) setTimes(["08:00"]);
    else setTimes(["all-day"]);
  }

  function save() {
    const patch = {
      name: name.trim(), type,
      target: requiresTarget ? Number(target) : null,
      unit: type === "check" || type === "yesno" ? null : unit.trim() || null,
      days, times,
    };
    if (isEdit) dispatch({ type: "editTask", id: taskId, patch });
    else dispatch({ type: "addTask", task: patch });
    onBack();
  }

  function remove() {
    if (window.confirm(`Delete "${existing.name}"? All history will be lost.`)) {
      dispatch({ type: "removeTask", id: taskId });
      onBack();
    }
  }

  const types = [
    ["check",   "Checkoff",      "Just done / not done"],
    ["count",   "Count to goal", "Log sets, sum to a target"],
    ["numeric", "Numeric value", "A single reading (e.g. weight)"],
    ["timer",   "Time / duration", "Track minutes spent"],
    ["yesno",   "Yes / No",      "Daily question"],
  ];

  // Suggest sensible unit defaults when type changes
  React.useEffect(() => {
    if (existing && type === existing.type) return; // keep existing
    if (type === "count" && !unit) setUnit("reps");
    if (type === "timer") setUnit("min");
    if (type === "numeric" && (unit === "reps" || unit === "min")) setUnit("kg");
  }, [type]);

  return (
    <StackScreen
      title={isEdit ? "Edit task" : "New task"}
      onBack={onBack}
      right={
        <button onClick={save} disabled={!validName || !validTarget}
          style={{ ...tMono(11, 600), color: validName && validTarget ? c.accent : c.dim2, background: "transparent", padding: "6px 0" }}>
          SAVE
        </button>
      }
    >
      <div>
        <div style={tLbl(c.dim)}>NAME</div>
        <input value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Push-ups"
          style={{ width: "100%", padding: "10px 0 14px", background: "transparent", border: "none",
            borderBottom: `1px solid ${c.rule}`, ...tH(22, 500), color: c.text, outline: "none" }} />
      </div>

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 8 }}>TYPE</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          {types.map(([id, label, sub]) => {
            const sel = id === type;
            return (
              <button key={id} onClick={() => setType(id)} style={{ width: "100%", textAlign: "left",
                display: "grid", gridTemplateColumns: "20px 1fr", gap: 12, padding: "12px 14px",
                border: `1px solid ${sel ? c.accent : c.rule}`, borderRadius: 10,
                background: sel ? c.accentSoft : "transparent", alignItems: "center" }}>
                <div style={{ width: 16, height: 16, borderRadius: "50%", border: `1.5px solid ${sel ? c.accent : c.dim2}`, position: "relative" }}>
                  {sel && <div style={{ position: "absolute", inset: 3, borderRadius: "50%", background: c.accent }} />}
                </div>
                <div>
                  <div style={{ ...tH(14, 500), color: c.text }}>{label}</div>
                  <div style={{ ...tMono(10), color: c.dim, marginTop: 2 }}>{sub.toUpperCase()}</div>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {(requiresTarget || type === "numeric") && (
        <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr", gap: 12 }}>
          {requiresTarget && (
            <div>
              <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>TARGET</div>
              <input type="number" value={target} onChange={e => setTarget(e.target.value)}
                style={{ width: "100%", padding: "10px 0", background: "transparent", border: "none",
                  borderBottom: `1px solid ${c.rule}`, ...tH(22, 500), color: c.text, outline: "none" }} />
            </div>
          )}
          <div style={{ gridColumn: requiresTarget ? "auto" : "1 / -1" }}>
            <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>UNIT</div>
            <input value={unit} onChange={e => setUnit(e.target.value)} placeholder="reps · oz · kg"
              style={{ width: "100%", padding: "10px 0", background: "transparent", border: "none",
                borderBottom: `1px solid ${c.rule}`, ...tH(22, 500), color: c.text, outline: "none" }} />
          </div>
        </div>
      )}

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 8 }}>DAYS</div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 4 }}>
          {DAY_LABELS.map((d, i) => {
            const a = days.includes(i);
            return (
              <button key={i} onClick={() => toggleDay(i)} style={{
                aspectRatio: "1", border: `1px solid ${a ? c.accent : c.rule}`,
                background: a ? c.accent : "transparent", color: a ? "#fff" : c.dim, borderRadius: 8,
                display: "flex", alignItems: "center", justifyContent: "center", ...tMono(13, 600) }}>{d}</button>
            );
          })}
        </div>
        <div style={{ display: "flex", gap: 6, marginTop: 8 }}>
          {[["Daily",[0,1,2,3,4,5,6]],["Weekdays",[0,1,2,3,4]],["M·W·F",[0,2,4]],["Weekends",[5,6]]].map(([lbl, arr]) => (
            <button key={lbl} onClick={() => setDays(arr)} style={{ padding: "6px 10px", borderRadius: 6, background: "transparent",
              border: `1px solid ${c.rule}`, ...tMono(10, 500), color: c.dim, letterSpacing: ".08em" }}>{lbl.toUpperCase()}</button>
          ))}
        </div>
      </div>

      <div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span style={tLbl(c.dim)}>TIMES</span>
          <button onClick={toggleAllDay} style={{ ...tMono(10, 500), color: c.dim, background: "transparent", letterSpacing: ".08em" }}>
            {times.includes("all-day") ? "USE SPECIFIC TIMES" : "ALL-DAY GOAL"}
          </button>
        </div>
        {times.includes("all-day") ? (
          <div style={{ padding: "16px 12px", marginTop: 6, background: c.accentSoft, color: c.accent, borderRadius: 10, ...tMono(13, 600), textAlign: "center" }}>
            ALL DAY — LOG ANY TIME
          </div>
        ) : (
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap", marginTop: 6 }}>
            {times.map((t, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 4, padding: "6px 6px 6px 10px", border: `1px solid ${c.rule}`, borderRadius: 8, background: c.bg2 }}>
                <input type="time" value={t} onChange={e => setTimeAt(i, e.target.value)}
                  style={{ background: "transparent", border: "none", outline: "none", ...tMono(13, 500), color: c.text, width: 70 }} />
                {times.length > 1 && (
                  <button onClick={() => removeTime(i)} style={{ ...tMono(10), color: c.dim, padding: "2px 6px", background: "transparent" }}><TIcon.X/></button>
                )}
              </div>
            ))}
            <button onClick={addTime} style={{ padding: "8px 12px", border: `1px dashed ${c.dim3}`, borderRadius: 8, ...tMono(11), color: c.dim, background: "transparent" }}>+ TIME</button>
          </div>
        )}
      </div>

      {isEdit && (
        <Btn variant="danger" onClick={remove} style={{ marginTop: "auto", alignSelf: "flex-start" }}>
          <TIcon.Trash/> Delete task
        </Btn>
      )}
    </StackScreen>
  );
}

// ─── Per-task stats screen ─────────────────────────
function TaskStatsScreen({ taskId, onBack }) {
  const { store, now } = useTallyStore();
  const { push } = useNav();
  const c = tallyColors(store.settings.dark);
  const task = store.tasks.find(t => t.id === taskId);
  if (!task) return <StackScreen title="Task not found" onBack={onBack} />;
  const today = now();

  // Build 30-day series
  const series = [];
  for (let i = 29; i >= 0; i--) {
    const d = addDays(today, -i);
    const s = taskStateFor(task, d, store.log, today);
    series.push({ d, state: s });
  }
  const scheduled = series.filter(s => s.state.status !== "off");
  const onTarget = scheduled.filter(s => s.state.status === "done").length;
  const sumValues = scheduled.map(s => s.state.sum || (s.state.value || 0)).filter(v => v != null);
  const total = sumValues.reduce((a, b) => a + b, 0);
  const avg = sumValues.length > 0 ? total / sumValues.length : 0;
  const best = sumValues.length > 0 ? Math.max(...sumValues) : 0;
  const rate = scheduled.length > 0 ? Math.round(onTarget / scheduled.length * 100) : 0;

  // Hourly heatmap
  const byHour = Array(24).fill(0);
  store.log.filter(l => l.taskId === taskId).forEach(l => {
    const h = parseInt(l.time.split(":")[0]); if (!Number.isNaN(h)) byHour[h]++;
  });
  const maxHour = Math.max(...byHour, 1);

  const recentEntries = store.log.filter(l => l.taskId === taskId).sort((a,b) => b.ts - a.ts).slice(0, 8);

  return (
    <StackScreen
      title={task.name}
      onBack={onBack}
      right={
        <div style={{ display: "flex", gap: 8 }}>
          <button onClick={() => push({ kind: "taskDetail", taskId })} style={{ ...tMono(11, 500), color: c.dim, background: "transparent" }}>LOG</button>
          <button onClick={() => push({ kind: "editTask", taskId })} style={{ ...tMono(11, 500), color: c.dim, background: "transparent" }}>EDIT</button>
        </div>
      }
    >
      <div>
        <div style={tLbl(c.dim)}>{task.name.toUpperCase()} · 30 DAYS</div>
        <h1 style={{ ...tH(28, 500), margin: "4px 0 0" }}>{task.name}</h1>
        <div style={{ ...tMono(11), color: c.dim, marginTop: 4 }}>
          {describeSchedule(task).days.toUpperCase()} · {task.type.toUpperCase()}{task.target ? ` · TARGET ${task.target} ${task.unit}` : ""}
        </div>
      </div>

      {/* Big bar chart */}
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <span style={tLbl(c.dim)}>{(task.type === "count" || task.type === "timer") ? "DAILY TOTAL" : task.type === "numeric" ? "DAILY VALUE" : "DAILY COMPLETION"}</span>
          {task.target && <span style={{ ...tMono(11), color: c.dim }}>GOAL · {task.target}</span>}
        </div>
        <div style={{ position: "relative", height: 140, marginTop: 12, display: "flex", gap: 2, alignItems: "flex-end" }}>
          {series.map(({ d, state }, i) => {
            const isToday = i === series.length - 1;
            const off = state.status === "off";
            let h;
            if (off) h = 6;
            else if (task.type === "count" || task.type === "timer") {
              h = state.pct * 100;
            } else if (task.type === "numeric") {
              // normalize against 1.2*best
              h = state.value != null ? ((state.value) / (best || 1)) * 70 + 10 : 6;
            } else {
              h = state.status === "done" ? 100 : state.pct > 0 ? 50 : 6;
            }
            const color = off ? c.dim3 : state.status === "done" ? c.accent : state.status === "partial" ? c.accentSoft : state.status === "overdue" ? c.neg : c.dim3;
            return (
              <div key={i} title={dateKey(d)} style={{ flex: 1, position: "relative", height: "100%" }}>
                <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: `${Math.min(h, 100)}%`, background: color, borderRadius: 2, opacity: isToday ? 1 : 0.85 }} />
                {isToday && <div style={{ position: "absolute", top: -14, left: 0, right: 0, ...tMono(8, 600), color: c.text, textAlign: "center" }}>NOW</div>}
              </div>
            );
          })}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8, ...tMono(10), color: c.dim }}>
          <span>−30D</span><span>−15D</span><span>TODAY</span>
        </div>
      </Card>

      {/* Stat tiles */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
        {(task.type === "count" || task.type === "timer") ? (
          <React.Fragment>
            <StatTile c={c} label="AVERAGE / DAY"  value={`${Math.round(avg)} ${task.unit || ""}`.trim()} />
            <StatTile c={c} label="BEST DAY"       value={`${Math.round(best)} ${task.unit || ""}`.trim()} />
            <StatTile c={c} label="TOTAL · 30D"    value={`${Math.round(total)}${task.unit ? " " + task.unit : ""}`} />
            <StatTile c={c} label="ON TARGET"      value={`${onTarget} / ${scheduled.length} days`} />
          </React.Fragment>
        ) : task.type === "numeric" ? (
          <React.Fragment>
            <StatTile c={c} label="LATEST"     value={`${sumValues[sumValues.length-1] ? Number(sumValues[sumValues.length-1]).toFixed(1) : "—"} ${task.unit || ""}`.trim()} />
            <StatTile c={c} label="AVERAGE"    value={`${Number(avg).toFixed(1)} ${task.unit || ""}`.trim()} />
            <StatTile c={c} label="LOG RATE"   value={`${rate}%`} />
            <StatTile c={c} label="ENTRIES"    value={`${sumValues.length}`} />
          </React.Fragment>
        ) : (
          <React.Fragment>
            <StatTile c={c} label="COMPLETION" value={`${rate}%`} />
            <StatTile c={c} label="DONE"       value={`${onTarget} / ${scheduled.length}`} />
          </React.Fragment>
        )}
      </div>

      {/* Hour heatmap */}
      {(task.type === "count" || task.type === "timer") && (
        <div>
          <div style={{ ...tLbl(c.dim), marginBottom: 8 }}>WHEN YOU LOG · HOUR DENSITY</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(24, 1fr)", gap: 1, height: 28 }}>
            {byHour.map((v, h) => (
              <div key={h} style={{ background: v === 0 ? c.dim3 : c.accent, opacity: v === 0 ? 1 : 0.3 + (v / maxHour) * 0.7, borderRadius: 1 }} />
            ))}
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4, ...tMono(9), color: c.dim }}>
            <span>00</span><span>06</span><span>12</span><span>18</span><span>24</span>
          </div>
        </div>
      )}

      {/* Recent entries */}
      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>RECENT ENTRIES</div>
        {recentEntries.length === 0 ? (
          <div style={{ ...tBody(13), color: c.dim, padding: "12px 0" }}>No entries yet.</div>
        ) : recentEntries.map(e => (
          <div key={e.id} style={{ display: "grid", gridTemplateColumns: "auto 1fr auto auto", padding: "10px 0", borderBottom: `1px solid ${c.rule}`, alignItems: "center", gap: 8 }}>
            <span style={{ ...tMono(10), color: c.dim }}>{e.date}</span>
            <span style={{ ...tMono(11), color: c.dim }}>{e.time}</span>
            <span style={{ ...tMono(14, 600), color: c.text }}>
              {e.value === true ? "✓" : e.value === false ? "✗" : typeof e.value === "number" ? (Number.isInteger(e.value) ? `+${e.value}` : `${Number(e.value).toFixed(1)}`) : String(e.value)}
            </span>
            <span style={{ ...tMono(10), color: c.dim }}>{task.unit?.toUpperCase() || ""}</span>
          </div>
        ))}
      </div>
    </StackScreen>
  );
}

function StatTile({ c, label, value }) {
  return (
    <div style={{ background: c.bg2, padding: 14, borderRadius: 10, border: `1px solid ${c.rule}` }}>
      <div style={tLbl(c.dim)}>{label}</div>
      <div style={{ ...tMono(20, 600), marginTop: 6, color: c.text }}>{value}</div>
    </div>
  );
}

Object.assign(window, { TasksScreen, TaskForm, TaskStatsScreen, StatTile });
