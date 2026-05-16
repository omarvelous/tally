We are building an iOS-first app called Tally.

Tally is a scheduled-todo streak app with a strict “100% the day or break the chain” philosophy.

Current stack:
- Swift 6.3.2
- SwiftUI
- SwiftData
- @Observable
- local-first/offline-first
- eventual CloudKit sync
- future possibility of custom backend/API
- future widgets + Siri/AppIntents

The current implementation plan is heavily local/on-device oriented, but I want to proactively evaluate the data architecture so we do not paint ourselves into a corner later.

I want you to act as a senior iOS systems architect and critically review the current planned model architecture and propose improvements specifically around:

1. SwiftData model structure
2. CloudKit compatibility
3. future server/API compatibility
4. offline-first sync safety
5. event sourcing / activity logging
6. auditability
7. undo/history integrity
8. timezone correctness
9. streak integrity
10. future analytics support
11. widget + AppIntent mutation consistency
12. conflict resolution considerations
13. long-term migration safety
14. performance considerations at scale
15. future cross-platform/web considerations

Here is the CURRENT planned model structure:

```swift
enum TaskType: String, Codable {
    case check
    case count
    case timer
    case numeric
    case yesno
}

@Model
final class TallyTask {
    var id: String

    var name: String
    var type: String

    var target: Double?
    var unit: String?

    var days: [Int]
    var times: [String]

    var notifPing: Bool
    var notifNag: Bool
    var notifSound: Bool

    var archived: Bool

    var createdAt: Double
}

@Model
final class LogEntry {
    var id: String

    var taskId: String

    var date: String
    var time: String

    var value: Double

    var ts: Double
}

@Model
final class TallySettings {
    var dark: Bool
    var density: String
    var showIcons: Bool

    var quietHoursEnabled: Bool
    var quietHoursStart: String
    var quietHoursEnd: String

    var hasOnboarded: Bool
}
```

Current architecture principles:

selector/business logic lives in pure functions
views should remain thin
SwiftData is persistence only
selectors derive task/day/streak state
app is local-first
CloudKit sync may come later
custom backend/API may come much later
current priority is MVP velocity

I specifically want you to deeply evaluate whether we should introduce:

explicit schedule models instead of primitive arrays
event/activity logging models
mutation service layers
soft deletion
UUID usage
versioning
device identity
sync metadata
append-only event patterns
timezone-aware logging
immutable history concepts

I want practical guidance, not theoretical overengineering.

Please provide:

architectural critique of the current models
specific recommended model changes
event/activity logging architecture recommendations
mutation flow recommendations
sync-readiness considerations
SwiftData + CloudKit pitfalls to avoid
what is safe to defer until later
what absolutely should be done NOW before implementation begins
recommended folder/service structure
examples of improved model definitions
considerations around future APIs and analytics
tradeoffs between simplicity vs future-proofing

Optimize for:

keeping MVP fast
avoiding catastrophic future rewrites
preserving streak/data integrity
staying idiomatic to Apple platforms
minimizing accidental architectural debt