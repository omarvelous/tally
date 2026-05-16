// Tally — UI atoms + navigation
// All components consume from useTallyStore() and the Nav context below.

// ─── Color palette (light + dark, single accent) ────
function tallyColors(dark) {
  return dark ? {
    bg:      "#0B0C10",
    bg2:     "#15171D",
    bg3:     "#1E2129",
    bg4:     "#2A2E38",
    text:    "#ECEAE4",
    dim:     "rgba(236,234,228,0.62)",
    dim2:    "rgba(236,234,228,0.32)",
    dim3:    "rgba(236,234,228,0.16)",
    rule:    "rgba(236,234,228,0.08)",
    accent:  "#7A8FFF",
    accentSoft: "rgba(122,143,255,0.16)",
    pos:     "#9EE6A8",
    neg:     "#FF8B72",
    warn:    "#FFD27A",
  } : {
    bg:      "#F7F5F1",
    bg2:     "#FFFFFF",
    bg3:     "#EFEBE3",
    bg4:     "#E5DFD2",
    text:    "#16161A",
    dim:     "rgba(22,22,26,0.55)",
    dim2:    "rgba(22,22,26,0.30)",
    dim3:    "rgba(22,22,26,0.14)",
    rule:    "rgba(22,22,26,0.08)",
    accent:  "#2440D7",
    accentSoft: "rgba(36,64,215,0.10)",
    pos:     "#1E7A36",
    neg:     "#B3331A",
    warn:    "#A36A12",
  };
}

const tallyFont = {
  sans: "'IBM Plex Sans', ui-sans-serif, sans-serif",
  mono: "'IBM Plex Mono', ui-monospace, monospace",
};

const tH    = (s, w=500) => ({ font: `${w} ${s}px/1.1 ${tallyFont.sans}`, letterSpacing: "-0.02em" });
const tMono = (s, w=500) => ({ font: `${w} ${s}px/1 ${tallyFont.mono}`, fontVariantNumeric: "tabular-nums" });
const tBody = (s, w=400) => ({ font: `${w} ${s}px/1.4 ${tallyFont.sans}` });
const tLbl  = (c) => ({ font: `500 9.5px/1 ${tallyFont.mono}`, letterSpacing: ".14em", textTransform: "uppercase", color: c });

// ─── Navigation context ─────────────────────────────
const TallyNavCtx = React.createContext(null);
function useNav() { return React.useContext(TallyNavCtx); }

function TallyNavProvider({ children }) {
  const [tab, setTab] = React.useState(0);
  const [stack, setStack] = React.useState([]); // overlays
  const api = React.useMemo(() => ({
    tab, setTab,
    stack,
    push: (overlay) => setStack(s => [...s, overlay]),
    pop:  () => setStack(s => s.slice(0, -1)),
    popAll: () => setStack([]),
    go:   (newTab) => { setTab(newTab); setStack([]); },
  }), [tab, stack]);
  return <TallyNavCtx.Provider value={api}>{children}</TallyNavCtx.Provider>;
}

// ─── Status bar — uses simulated clock ───────────────
function TallyStatusBar({ tone }) {
  const { now } = useTallyStore();
  const d = now();
  const time = `${d.getHours()}:${pad2(d.getMinutes())}`;
  const color = tone === "dark" ? "#0a0b0e" : "#fff";
  return (
    <div style={{ position: "relative", height: 54, padding: "18px 32px 0",
      display: "flex", justifyContent: "space-between", alignItems: "flex-start",
      font: `600 17px/1 ${tallyFont.sans}`, color,
      fontVariantNumeric: "tabular-nums", zIndex: 5, pointerEvents: "none", letterSpacing: "-0.02em" }}>
      <div>{time}</div>
      <div style={{ position: "absolute", left: "50%", top: 11, width: 124, height: 36, borderRadius: 18, background: "#000", transform: "translateX(-50%)" }} />
      <div style={{ display: "flex", gap: 6, alignItems: "center" }} aria-hidden>
        <svg width="18" height="11" viewBox="0 0 18 11" fill="none"><path d="M1 8.5 4 5.5 7 8.5 16 1" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" opacity=".9"/></svg>
        <svg width="16" height="11" viewBox="0 0 16 11" fill={color}><path d="M9.5 4.7c1.3 0 2.5.5 3.5 1.4l.7-.7C12.5 4.3 11 3.7 9.5 3.7s-3 .6-4.2 1.7l.7.7c1-.9 2.2-1.4 3.5-1.4Zm0 2.5c.7 0 1.3.3 1.8.7l.7-.7c-.7-.6-1.5-1-2.5-1s-1.8.4-2.5 1l.7.7c.5-.4 1.1-.7 1.8-.7Z" opacity=".85"/></svg>
        <svg width="26" height="12" viewBox="0 0 26 12" fill="none"><rect x="0.5" y="0.5" width="22" height="11" rx="3" stroke={color} strokeOpacity=".4"/><rect x="2" y="2" width="19" height="8" rx="1.5" fill={color}/><rect x="23" y="4" width="2" height="4" rx="1" fill={color} fillOpacity=".4"/></svg>
      </div>
    </div>
  );
}

// ─── Tab bar ─────────────────────────────────────────
function TabIcon({ name }) {
  const props = { width: 18, height: 18, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.6, strokeLinecap: "round", strokeLinejoin: "round" };
  switch (name) {
    case "today":   return <svg {...props}><rect x="4" y="5" width="16" height="16" rx="2"/><path d="M9 3v4M15 3v4M4 11h16"/></svg>;
    case "tasks":   return <svg {...props}><path d="M5 6h14M5 12h14M5 18h14"/><circle cx="5" cy="6" r="1.2" fill="currentColor"/><circle cx="5" cy="12" r="1.2" fill="currentColor"/><circle cx="5" cy="18" r="1.2" fill="currentColor"/></svg>;
    case "add":     return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/></svg>;
    case "streak":  return <svg {...props}><path d="M4 18 8 14 12 16 16 10 20 12"/></svg>;
    case "more":    return <svg {...props}><circle cx="12" cy="12" r="9"/><circle cx="12" cy="8" r="1.2" fill="currentColor"/><path d="M12 12v5"/></svg>;
    default: return null;
  }
}

function TallyTabBar() {
  const { tab, setTab, popAll, push } = useNav();
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const items = [
    ["today",  "Today"],
    ["tasks",  "Tasks"],
    ["add",    "Add"],
    ["streak", "Streak"],
    ["more",   "More"],
  ];
  return (
    <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 86, padding: "10px 12px 28px",
      borderTop: `1px solid ${c.rule}`, background: c.bg, display: "flex", justifyContent: "space-between", zIndex: 10 }}>
      {items.map(([key, label], i) => {
        const a = i === tab;
        return (
          <button key={key} onClick={() => {
            if (key === "add") { push({ kind: "addTask" }); return; }
            setTab(i); popAll();
          }} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 5, color: a ? c.accent : c.dim, background: "transparent" }}>
            <TabIcon name={key} />
            <span style={{ font: `500 10px/1 ${tallyFont.sans}` }}>{label}</span>
          </button>
        );
      })}
    </div>
  );
}

// ─── Phone shell ─────────────────────────────────────
function TallyPhone({ children }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{
      position: "relative",
      width: 393, height: 852, borderRadius: 48, overflow: "hidden",
      background: c.bg, color: c.text,
      boxShadow: store.settings.dark
        ? "0 0 0 1px rgba(255,255,255,0.06), 0 24px 60px -20px rgba(0,0,0,0.6), 0 8px 20px -8px rgba(0,0,0,0.3)"
        : "0 1px 0 rgba(255,255,255,0.5) inset, 0 0 0 1px rgba(0,0,0,0.06), 0 24px 60px -20px rgba(0,0,0,0.18), 0 8px 20px -8px rgba(0,0,0,0.08)",
      fontFeatureSettings: '"ss01", "cv11"',
      WebkitFontSmoothing: "antialiased",
    }}>
      <TallyStatusBar tone={store.settings.dark ? "light" : "dark"} />
      {children}
      <TallyTabBar />
      {/* Home indicator */}
      <div style={{ position: "absolute", left: "50%", bottom: 9, width: 134, height: 5, borderRadius: 3,
        background: store.settings.dark ? "rgba(255,255,255,0.85)" : "rgba(10,11,14,0.85)",
        transform: "translateX(-50%)", zIndex: 11, pointerEvents: "none" }} />
    </div>
  );
}

// ─── Screen scaffold ─────────────────────────────────
function Screen({ children, padTop = 8 }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{ position: "absolute", top: 54, left: 0, right: 0, bottom: 86, overflowY: "auto", overflowX: "hidden",
      padding: `${padTop}px 22px 24px`, display: "flex", flexDirection: "column", gap: store.settings.density === "compact" ? 14 : 18,
      background: c.bg, color: c.text, font: `400 14px/1.4 ${tallyFont.sans}` }}>
      {children}
    </div>
  );
}

// Top header bar inside a screen — title + optional right button
function Header({ kicker, title, right }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <header style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
      <div>
        {kicker && <div style={tLbl(c.dim)}>{kicker}</div>}
        <h1 style={{ ...tH(32, 500), margin: kicker ? "4px 0 0" : 0 }}>{title}</h1>
      </div>
      {right}
    </header>
  );
}

// ─── Status pip (per task status) ───────────────────
function StatusPip({ status, size = 8 }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const colorMap = { done: c.pos, partial: c.accent, due: c.dim2, overdue: c.neg, off: c.dim3 };
  return <div style={{ width: size, height: size, borderRadius: "50%", background: colorMap[status] || c.dim2, flex: "0 0 auto" }} />;
}

// ─── Sparkline ──────────────────────────────────────
function Spark({ values, w = 56, h = 18, color, dim }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  if (!values || values.length === 0) return <div style={{ width: w, height: h }} />;
  const pts = values.map((v, i) => [(i / Math.max(values.length - 1, 1)) * (w - 2) + 1, h - 1 - v * (h - 2)]);
  const d = pts.map((p, i) => `${i ? "L" : "M"}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(" ");
  const last = values[values.length - 1];
  const stroke = last < 0.7 ? (dim || c.dim2) : (color || c.accent);
  return (
    <svg width={w} height={h} style={{ display: "block" }}>
      <path d={d} stroke={stroke} fill="none" strokeWidth="1.2" strokeLinecap="round"/>
      {/* last dot */}
      <circle cx={pts[pts.length-1][0]} cy={pts[pts.length-1][1]} r="2" fill={stroke}/>
    </svg>
  );
}

// ─── Progress bar ───────────────────────────────────
function Bar({ pct, height = 6, color, track, radius = 3, style }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{ height, background: track || c.bg3, borderRadius: radius, overflow: "hidden", ...style }}>
      <div style={{ width: `${Math.min(pct, 1) * 100}%`, height: "100%", background: color || c.accent, borderRadius: radius }} />
    </div>
  );
}

// ─── Ring (circular progress) ───────────────────────
function CircRing({ size = 56, stroke = 5, pct, color, track }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const r = size / 2 - stroke / 2;
  const circ = 2 * Math.PI * r;
  return (
    <svg width={size} height={size} style={{ display: "block" }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={track || c.bg3} strokeWidth={stroke}/>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color || c.accent} strokeWidth={stroke}
        strokeDasharray={circ} strokeDashoffset={circ * (1 - Math.min(pct, 1))} strokeLinecap="round"
        transform={`rotate(-90 ${size/2} ${size/2})`}/>
    </svg>
  );
}

// ─── Button ─────────────────────────────────────────
function Btn({ variant = "primary", children, full, onClick, style, disabled }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  const base = {
    padding: "13px 18px", borderRadius: 10, border: "none", cursor: "pointer",
    ...tH(14, 500),
    display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
    width: full ? "100%" : "auto",
    opacity: disabled ? 0.4 : 1,
    transition: "background .12s",
  };
  const variants = {
    primary:   { background: c.accent, color: "#fff" },
    secondary: { background: c.bg2,    color: c.text, border: `1px solid ${c.rule}` },
    ghost:     { background: "transparent", color: c.text },
    danger:    { background: "transparent", color: c.neg },
    accentSoft:{ background: c.accentSoft, color: c.accent },
  };
  return <button disabled={disabled} onClick={onClick} style={{ ...base, ...variants[variant], ...style }}>{children}</button>;
}

// ─── Sheet — modal-style overlay ────────────────────
function Sheet({ title, onClose, children, fullHeight = false }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{ position: "absolute", inset: 0, zIndex: 20, display: "flex", alignItems: "flex-end" }}>
      <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.4)", backdropFilter: "blur(2px)" }} />
      <div style={{
        position: "relative", width: "100%",
        height: fullHeight ? "calc(100% - 30px)" : "auto",
        maxHeight: "calc(100% - 30px)",
        background: c.bg, borderTopLeftRadius: 28, borderTopRightRadius: 28,
        padding: "10px 20px 28px",
        boxShadow: "0 -8px 24px rgba(0,0,0,0.18)",
        display: "flex", flexDirection: "column", gap: 14,
        overflow: "hidden",
      }}>
        <div style={{ width: 36, height: 4, background: c.dim3, borderRadius: 2, margin: "4px auto 6px" }} />
        {title && (
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 4 }}>
            <h2 style={{ ...tH(20, 500), margin: 0 }}>{title}</h2>
            <button onClick={onClose} style={{ ...tMono(11), color: c.dim, padding: "6px 10px", background: "transparent", border: "none" }}>CLOSE</button>
          </div>
        )}
        <div style={{ flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: 14 }}>{children}</div>
      </div>
    </div>
  );
}

// ─── Full-screen overlay (push from stack) ──────────
function StackScreen({ title, onBack, right, children }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{ position: "absolute", top: 54, left: 0, right: 0, bottom: 86, background: c.bg, color: c.text,
      display: "flex", flexDirection: "column", zIndex: 15 }}>
      <div style={{ padding: "10px 16px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: `1px solid ${c.rule}`, gap: 10 }}>
        <button onClick={onBack} style={{ ...tMono(11, 500), color: c.dim, padding: "8px 10px 8px 0", background: "transparent" }}>← BACK</button>
        {title && <span style={{ ...tH(14, 500), color: c.text, flex: 1, textAlign: "center" }}>{title}</span>}
        <div style={{ minWidth: 60, textAlign: "right" }}>{right}</div>
      </div>
      <div style={{ flex: 1, overflowY: "auto", padding: "12px 22px 22px", display: "flex", flexDirection: "column", gap: 16 }}>
        {children}
      </div>
    </div>
  );
}

// ─── Toggle ────────────────────────────────────────
function Toggle({ value, onChange }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <button onClick={() => onChange(!value)} style={{
      width: 38, height: 22, borderRadius: 11, background: value ? c.accent : c.dim3, position: "relative",
      transition: "background .15s", border: "none", padding: 0,
    }}>
      <div style={{ position: "absolute", top: 2, left: value ? 18 : 2, width: 18, height: 18, background: "#fff", borderRadius: 9, transition: "left .15s", boxShadow: "0 1px 2px rgba(0,0,0,.15)" }} />
    </button>
  );
}

// ─── Card / outlined box ───────────────────────────
function Card({ children, style, soft }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{
      background: soft ? c.accentSoft : c.bg2,
      borderRadius: 14, padding: 16,
      border: soft ? `1px solid transparent` : `1px solid ${c.rule}`,
      ...style,
    }}>{children}</div>
  );
}

// ─── Empty state ───────────────────────────────────
function Empty({ title, body, action }) {
  const { store } = useTallyStore();
  const c = tallyColors(store.settings.dark);
  return (
    <div style={{ padding: "40px 8px", textAlign: "center" }}>
      <div style={{ ...tH(18, 500), color: c.text }}>{title}</div>
      <div style={{ ...tBody(13), color: c.dim, marginTop: 6, maxWidth: 240, margin: "6px auto 0" }}>{body}</div>
      {action && <div style={{ marginTop: 16, display: "flex", justifyContent: "center" }}>{action}</div>}
    </div>
  );
}

// ─── Icons set (small util icons used throughout) ──
const TIcon = {
  Plus:   (p) => <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" {...p}><path d="M12 5v14M5 12h14"/></svg>,
  Check:  (p) => <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="m5 12 5 5L20 7"/></svg>,
  X:      (p) => <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" {...p}><path d="M6 6l12 12M6 18 18 6"/></svg>,
  Chev:   (p) => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="m9 6 6 6-6 6"/></svg>,
  Bell:   (p) => <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" {...p}><path d="M6 16h12l-1.5-2v-4a4.5 4.5 0 0 0-9 0v4z"/><path d="M10 19a2 2 0 0 0 4 0"/></svg>,
  Edit:   (p) => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" {...p}><path d="M4 20h4l10-10-4-4L4 16v4z"/></svg>,
  Trash:  (p) => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" {...p}><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/></svg>,
  Clock:  (p) => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>,
  Fast:   (p) => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" {...p}><path d="m13 3-7 11h5l-1 7 7-11h-5l1-7z"/></svg>,
};

Object.assign(window, {
  tallyColors, tallyFont, tH, tMono, tBody, tLbl,
  TallyNavCtx, useNav, TallyNavProvider,
  TallyPhone, TallyStatusBar, TallyTabBar, Screen, Header,
  StatusPip, Spark, Bar, CircRing, Btn, Sheet, StackScreen, Toggle, Card, Empty, TIcon,
});
