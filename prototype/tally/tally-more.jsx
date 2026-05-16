// Tally — Settings, Notifications, Onboarding, Demo time-travel controls.

function MoreScreen() {
  const { store, dispatch, now } = useTallyStore();
  const { push } = useNav();
  const c = tallyColors(store.settings.dark);

  return (
    <Screen>
      <Header kicker="SETTINGS" title="More" />

      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <div style={{ ...tH(16, 500) }}>Alex</div>
            <div style={{ ...tMono(11), color: c.dim, marginTop: 4 }}>{store.tasks.filter(t => !t.archived).length} ACTIVE TASKS</div>
          </div>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: c.accent, color: "#fff",
            display: "flex", alignItems: "center", justifyContent: "center", ...tH(18, 600) }}>A</div>
        </div>
      </Card>

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>APPEARANCE</div>
        <SettingRow label="Dark mode" right={<Toggle value={store.settings.dark} onChange={v => dispatch({ type: "settings", patch: { dark: v } })}/>} />
        <SettingRow label="Density" right={
          <div style={{ display: "flex", gap: 4 }}>
            {["regular", "compact"].map(d => (
              <button key={d} onClick={() => dispatch({ type: "settings", patch: { density: d } })} style={{
                padding: "5px 10px", borderRadius: 6,
                background: store.settings.density === d ? c.accent : "transparent",
                color: store.settings.density === d ? "#fff" : c.dim,
                ...tMono(10, 600), letterSpacing: ".08em", border: `1px solid ${c.rule}` }}>{d.toUpperCase()}</button>
            ))}
          </div>
        } />
        <SettingRow label="Show icons" right={<Toggle value={store.settings.icons} onChange={v => dispatch({ type: "settings", patch: { icons: v } })}/>} />
      </div>

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>NOTIFICATIONS</div>
        <NavRow label="Reminders" sub="Per-task notifications · quiet hours" onClick={() => push({ kind: "notif" })} />
      </div>

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>TASKS</div>
        <NavRow label={`Manage tasks (${store.tasks.length})`} sub="Edit · archive · delete" onClick={() => push({ kind: "manage" })} />
        <NavRow label="Add task" sub="New scheduled task" onClick={() => push({ kind: "addTask" })} />
      </div>

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>DEMO · TIME-TRAVEL</div>
        <div style={{ ...tBody(11), color: c.dim, padding: "0 0 8px" }}>
          Move the simulated clock forward to test the streak mechanics.
        </div>
        <DemoClockControls />
      </div>

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 4 }}>DATA</div>
        <NavRow label="View onboarding" sub="Replay the welcome screen" onClick={() => push({ kind: "onboard" })} />
        <NavRow label="Reset prototype" sub="Wipe data and reseed" danger onClick={() => {
          if (window.confirm("Reset all data? This rewrites localStorage with fresh sample tasks.")) {
            dispatch({ type: "reset" });
          }
        }} />
      </div>

      <div style={{ textAlign: "center", padding: "12px 0 4px", ...tMono(10), color: c.dim, letterSpacing: ".14em" }}>
        TALLY · v1.0 · PROTOTYPE
      </div>
    </Screen>
  );
}

function SettingRow({ label, sub, right }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{ display: "grid", gridTemplateColumns: "1fr auto", padding: "13px 0", borderBottom: `1px solid ${c.rule}`, alignItems: "center", gap: 12 }}>
      <div>
        <div style={{ ...tH(14, 500), color: c.text }}>{label}</div>
        {sub && <div style={{ ...tMono(10), color: c.dim, marginTop: 2 }}>{sub.toUpperCase()}</div>}
      </div>
      {right}
    </div>
  );
}

function NavRow({ label, sub, onClick, danger }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <button onClick={onClick} style={{ width: "100%", display: "grid", gridTemplateColumns: "1fr auto", gap: 10,
      padding: "13px 0", borderBottom: `1px solid ${c.rule}`, alignItems: "center",
      background: "transparent", textAlign: "left" }}>
      <div>
        <div style={{ ...tH(14, 500), color: danger ? c.neg : c.text }}>{label}</div>
        {sub && <div style={{ ...tMono(10), color: c.dim, marginTop: 2 }}>{sub.toUpperCase()}</div>}
      </div>
      <TIcon.Chev style={{ color: c.dim }}/>
    </button>
  );
}

// ─── Demo time-travel ─────────────────────────────
function DemoClockControls() {
  const { store, dispatch, now } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const offsetH = Math.round(store.clockOffset / (60 * 60 * 1000) * 10) / 10;
  const d = now();
  const displayTime = `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
  const displayDate = `${DAY_NAMES[dayOfWeek(d)]} ${MONTH_NAMES_SHORT[d.getMonth()]} ${d.getDate()}`;

  function bump(ms) { dispatch({ type: "advanceClock", deltaMs: ms }); }

  return (
    <div style={{ background: c.bg2, borderRadius: 12, padding: 14, border: `1px solid ${c.rule}` }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div>
          <div style={tLbl(c.dim)}>SIMULATED NOW</div>
          <div style={{ ...tH(22, 500), color: c.accent, marginTop: 4 }}>{displayTime}</div>
          <div style={{ ...tMono(11), color: c.dim, marginTop: 2 }}>{displayDate.toUpperCase()}</div>
        </div>
        <button onClick={() => dispatch({ type: "resetClock" })}
          style={{ ...tMono(10, 600), color: c.dim, padding: "6px 10px", background: "transparent", letterSpacing: ".1em", border: `1px solid ${c.rule}`, borderRadius: 6 }}>
          RESET
        </button>
      </div>
      <div style={{ ...tMono(10), color: c.dim, marginTop: 8 }}>
        OFFSET: {offsetH >= 0 ? "+" : ""}{offsetH}h
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6, marginTop: 12 }}>
        {[
          ["+1h",  60 * 60 * 1000],
          ["+4h",  4 * 60 * 60 * 1000],
          ["+1d",  24 * 60 * 60 * 1000],
          ["+1wk", 7 * 24 * 60 * 60 * 1000],
        ].map(([lbl, ms]) => (
          <button key={lbl} onClick={() => bump(ms)} style={{
            padding: "10px 0", borderRadius: 8, border: `1px solid ${c.rule}`,
            background: c.bg, color: c.text, ...tMono(12, 600) }}>{lbl}</button>
        ))}
      </div>
    </div>
  );
}

// ─── Notifications config screen ──────────────────
function NotifScreen({ onBack }) {
  const { store, dispatch } = useTallyStore();
  const c = tallyColors(store.settings.dark);

  // Use a side-store inside settings for notification config — keyed by task id.
  // For prototype simplicity, store on the task itself as `notif`.
  const tasks = store.tasks.filter(t => !t.archived);

  function patchNotif(taskId, patch) {
    const t = tasks.find(x => x.id === taskId);
    dispatch({ type: "editTask", id: taskId, patch: { notif: { ping: true, nag: false, sound: true, ...t.notif, ...patch } } });
  }

  return (
    <StackScreen title="Reminders" onBack={onBack}>
      <div>
        <div style={tLbl(c.dim)}>SETTINGS</div>
        <h1 style={{ ...tH(28, 500), margin: "4px 0 0" }}>Reminders</h1>
      </div>

      {/* Quiet hours */}
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <div style={{ ...tH(15, 500) }}>Quiet hours</div>
            <div style={{ ...tMono(11), color: c.dim, marginTop: 4 }}>22:00 — 06:30 · NO PINGS</div>
          </div>
          <Toggle value={true} onChange={() => {}} />
        </div>
      </Card>

      <div>
        <div style={{ ...tLbl(c.dim), marginBottom: 8 }}>PER TASK</div>
        {tasks.map(t => {
          const n = t.notif || { ping: true, nag: false, sound: true };
          return (
            <div key={t.id} style={{ padding: "14px 0", borderBottom: `1px solid ${c.rule}` }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
                <span style={{ ...tH(14, 500) }}>{t.name}</span>
                <span style={{ ...tMono(10), color: c.dim }}>{t.times.join(" · ").toUpperCase()}</span>
              </div>
              <div style={{ display: "flex", gap: 6, marginTop: 8, flexWrap: "wrap" }}>
                <NotifChip c={c} label="PING"     active={n.ping}  onClick={() => patchNotif(t.id, { ping: !n.ping })} />
                <NotifChip c={c} label="NAG +15"  active={n.nag}   onClick={() => patchNotif(t.id, { nag: !n.nag })} />
                <NotifChip c={c} label="SOUND"    active={n.sound} onClick={() => patchNotif(t.id, { sound: !n.sound })} />
              </div>
            </div>
          );
        })}
      </div>
    </StackScreen>
  );
}

function NotifChip({ c, label, active, onClick }) {
  return (
    <button onClick={onClick} style={{ padding: "5px 10px",
      background: active ? c.accent : "transparent",
      color: active ? "#fff" : c.dim,
      ...tMono(10, 700), letterSpacing: ".1em",
      border: `1px solid ${active ? c.accent : c.rule}`, borderRadius: 6,
      cursor: "pointer" }}>{label}</button>
  );
}

// ─── Manage tasks (archive list) ──────────────────
function ManageScreen({ onBack }) {
  const { store, dispatch } = useTallyStore();
  const { push } = useNav();
  const c = tallyColors(store.settings.dark);

  return (
    <StackScreen title="Manage tasks" onBack={onBack}>
      <div>
        <div style={tLbl(c.dim)}>{store.tasks.length} TOTAL</div>
        <h1 style={{ ...tH(28, 500), margin: "4px 0 0" }}>Manage</h1>
      </div>

      {store.tasks.map(t => (
        <div key={t.id} style={{ display: "grid", gridTemplateColumns: "1fr auto auto auto", gap: 10, padding: "12px 0", borderBottom: `1px solid ${c.rule}`, alignItems: "center" }}>
          <div>
            <div style={{ ...tH(14, 500), color: t.archived ? c.dim : c.text }}>{t.name}</div>
            <div style={{ ...tMono(10), color: c.dim, marginTop: 2 }}>
              {describeSchedule(t).days.toUpperCase()} · {t.type.toUpperCase()}{t.archived ? " · ARCHIVED" : ""}
            </div>
          </div>
          <button onClick={() => push({ kind: "editTask", taskId: t.id })} style={{ ...tMono(10, 600), color: c.accent, padding: "6px 8px", background: "transparent", letterSpacing: ".08em" }}>EDIT</button>
          <button onClick={() => dispatch({ type: "archiveTask", id: t.id })} style={{ ...tMono(10, 600), color: c.dim, padding: "6px 8px", background: "transparent", letterSpacing: ".08em" }}>{t.archived ? "RESTORE" : "ARCHIVE"}</button>
          <button onClick={() => {
            if (window.confirm(`Delete "${t.name}"?`)) dispatch({ type: "removeTask", id: t.id });
          }} style={{ ...tMono(10, 600), color: c.neg, padding: "6px 8px", background: "transparent", letterSpacing: ".08em" }}>DEL</button>
        </div>
      ))}
    </StackScreen>
  );
}

// ─── Onboarding screen ────────────────────────────
function OnboardScreen({ onBack }) {
  const { store, now } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const today = now();
  const streak = streakFor(store.tasks, store.log, today);

  return (
    <StackScreen title="" onBack={onBack}>
      <div style={tLbl(c.dim)}>TALLY · v1.0</div>

      <div>
        <h1 style={{ ...tH(56, 500), letterSpacing: "-0.04em" }}>
          One rule.<br/>
          <span style={{ color: c.accent }}>100% the day.</span>
        </h1>
        <p style={{ ...tBody(15), color: c.dim, marginTop: 16, maxWidth: 320 }}>
          Schedule tasks at times that matter. Hit every one — earn the day. Miss any — break the chain.
        </p>
      </div>

      {/* Live demo strip */}
      <div>
        <div style={tLbl(c.dim)}>YOUR LAST 30 DAYS</div>
        <div style={{ display: "flex", gap: 2, marginTop: 8, height: 30 }}>
          {streak.history.slice(-30).map((d, i) => (
            <div key={i} style={{ flex: 1, background: d.pct >= 1 ? c.accent : d.pct >= 0.5 ? c.accentSoft : c.dim3, borderRadius: 1 }}/>
          ))}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4, ...tMono(10), color: c.dim }}>
          <span>—30D</span><span style={{ color: c.accent }}>STREAK · {streak.current}D</span>
        </div>
      </div>

      <ul style={{ marginTop: 8, display: "flex", flexDirection: "column", padding: 0, listStyle: "none" }}>
        {[
          ["SCHEDULE", "Pick days, set times"],
          ["LOG ITERATIVELY", "Add sets toward a daily goal"],
          ["GRACE TILL MIDNIGHT", "Catch up before the day flips"],
          ["TRACK EVERYTHING", "Every task, every day"],
        ].map((r, i) => (
          <li key={i} style={{ display: "grid", gridTemplateColumns: "30px 130px 1fr", gap: 12, padding: "12px 0", borderTop: `1px solid ${c.rule}` }}>
            <span style={{ ...tMono(11), color: c.dim }}>{String(i+1).padStart(2,"0")}</span>
            <span style={{ ...tH(13, 500), color: c.text }}>{r[0]}</span>
            <span style={{ ...tBody(13), color: c.dim }}>{r[1]}</span>
          </li>
        ))}
      </ul>

      <Btn variant="primary" full onClick={onBack} style={{ marginTop: 16 }}>Start tallying →</Btn>
    </StackScreen>
  );
}

Object.assign(window, { MoreScreen, NotifScreen, ManageScreen, OnboardScreen });
