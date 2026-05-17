# Widgets

Tally provides two WidgetKit widgets for quick status checks without opening the app.

## Streak Widget

Shows your current streak count at a glance.

### Supported Sizes

| Placement | Size | Content |
|-----------|------|---------|
| Lock screen | Circular | Streak count in large monospace type |
| Lock screen | Rectangular | Streak count + day completion % + progress bar |
| Home screen | Small | Large streak number, completion %, done/total |

### Refresh

Timeline refreshes at the next midnight (local time), since streak state only changes at day boundaries.

## Today Checklist Widget

A quick view of today's scheduled tasks and their completion status.

### Supported Sizes

| Placement | Size | Content |
|-----------|------|---------|
| Home screen | Medium | Date header, up to 6 tasks with status indicators |

### Task Display

- Green filled circle = done
- Empty circle = pending/overdue
- Shows task name and progress label (e.g., "100/100 reps", "Done", "—")

### Refresh

Same as streak widget — next midnight.

## Technical Notes

- Both widgets read from the shared SwiftData store via `ModelContainerFactory`
- Widgets are read-only — tap to open the main app for logging
- Placeholder data shown in the widget gallery uses realistic demo content
- All state computation uses the same pure selector functions as the main app
