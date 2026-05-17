# Tally

**One rule: 100% the day.**

Tally is a streak-based habit tracker for iOS. A day is earned only when every scheduled task hits 100% completion by midnight. No grace days, no freezes, no partial credit — miss one task and the streak resets.

## Core Concept

Most habit trackers reward showing up. Tally rewards *finishing*. The streak mechanic is deliberately unforgiving because that's what makes it meaningful.

- Schedule tasks for specific days and times
- Log completions throughout the day
- Hit 100% before midnight to earn the day
- Consecutive earned days build your streak

## Task Types

| Type | Example | Completion |
|------|---------|------------|
| **Check** | "Take vitamins" | Tap once to mark done |
| **Count** | "100 pushups" | Log sets until target reached |
| **Timer** | "Read 30 min" | Log minutes until target reached |
| **Numeric** | "Weigh in" | Record a single reading |
| **Yes/No** | "Did you stretch?" | Answer yes or no |

## Screenshots

*Coming soon — app is in pre-release.*

## Architecture

```
Tally/
├── Models/       SwiftData @Model classes
├── Logic/        Pure selectors — no side effects
├── Views/        SwiftUI screens (Today, Tasks, Streak, More)
├── Services/     Notifications, midnight observer, container factory
├── Design/       Colors, typography tokens
└── Intents/      Siri Shortcuts integration
```

All state is derived from immutable `LogEntry` records. There is no cached streak counter — streaks, completion percentages, and task status are computed on demand from the log.

## Tech Stack

- Swift & SwiftUI (iOS 18.0+)
- SwiftData for persistence
- WidgetKit (streak + today checklist widgets)
- App Intents for Siri/Shortcuts logging
- CloudKit for sync (via SwiftData)

## Building

Requires Xcode 26+ and an iOS 18.0+ simulator or device.

```bash
xcodebuild -scheme Tally \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

## Testing

```bash
xcodebuild -scheme Tally \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

## Project Structure

See [docs/architecture.md](docs/architecture.md) for a detailed breakdown of the codebase.

## License

Private — not open source.
