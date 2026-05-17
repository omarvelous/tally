# Tally — Project Conventions

## Stack
- **Swift 6.3.2**, iOS 18.0 deployment target
- **SwiftUI** for all views, **SwiftData** for persistence
- `@Observable` for view models (never `ObservableObject`)
- Xcode 26.5 — project file is committed (no XcodeGen)

## Build & Test
```
xcodebuild -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Architecture
- **Models** in `Tally/Models/` — SwiftData `@Model` classes, dumb data containers
- **Selectors** in `Tally/Logic/` — pure free functions, no side effects, no model methods
- **Design tokens** in `Tally/Design/` — colors, typography
- **Views** in `Tally/Views/` — grouped by screen (Today/, Tasks/, Streak/, More/, Components/)
- **Services** in `Tally/Services/` — notifications, midnight observer, seed data

## Key Rules
- `spec.md` is the source of truth for product behavior
- `prototype/` contains the HTML/React prototype for visual reference
- Dates stored as `String` ("YYYY-MM-DD"), times as `String` ("HH:MM") — never re-derive from timestamps
- `LogEntry.value` is always `Double` — booleans mapped to 1.0/0.0, task type disambiguates
- Tests are the priority for logic — every selector gets tests before UI work
- No storyboards, no UIKit unless required for system integration
