// Tally — root app: providers, tab routing, stack overlays.

function Tabs() {
  const { tab, stack, pop, push } = useNav();

  // Top-of-stack overlay takes priority
  const overlay = stack[stack.length - 1];
  if (overlay) {
    return <OverlayRouter overlay={overlay} onBack={pop} />;
  }

  // Tab content
  switch (tab) {
    case 0: return <TodayScreen />;
    case 1: return <TasksScreen />;
    case 3: return <StreakScreen />;
    case 4: return <MoreScreen />;
    default: return <TodayScreen />;
  }
}

// Stack screens get full-screen behavior; modal-style "addTask" uses a Sheet
function OverlayRouter({ overlay, onBack }) {
  switch (overlay.kind) {
    case "addTask":   return <TaskForm onBack={onBack} />;
    case "editTask":  return <TaskForm taskId={overlay.taskId} onBack={onBack} />;
    case "taskDetail":return <TaskDetail taskId={overlay.taskId} onBack={onBack} />;
    case "taskStats": return <TaskStatsScreen taskId={overlay.taskId} onBack={onBack} />;
    case "dayDetail": return <DayDetail date={overlay.date} onBack={onBack} />;
    case "notif":     return <NotifScreen onBack={onBack} />;
    case "manage":    return <ManageScreen onBack={onBack} />;
    case "onboard":   return <OnboardScreen onBack={onBack} />;
    default: return null;
  }
}

function App() {
  return (
    <TallyProvider>
      <TallyNavProvider>
        <PageBackground>
          <TallyPhone>
            <Tabs />
          </TallyPhone>
        </PageBackground>
      </TallyNavProvider>
    </TallyProvider>
  );
}

function PageBackground({ children }) {
  return (
    <div style={{
      minHeight: "100vh",
      display: "flex", alignItems: "center", justifyContent: "center",
      padding: 30,
      background: "radial-gradient(120% 80% at 50% 0%, #efece4 0%, #e6e2d8 60%, #d8d3c4 100%)",
    }}>
      {children}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
