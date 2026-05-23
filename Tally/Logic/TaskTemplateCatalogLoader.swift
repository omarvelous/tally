//
//  TaskTemplateCatalogLoader.swift
//  Tally
//
//  Pure functions for loading and converting task templates.

import Foundation
import SwiftUI

/// Load and decode the bundled task template catalog.
func loadTemplateCatalog() -> TaskTemplateCatalog {
    guard let url = Bundle.main.url(forResource: "task_templates", withExtension: "json"),
          let data = try? Data(contentsOf: url) else {
        fatalError("Missing task_templates.json in app bundle")
    }
    do {
        return try JSONDecoder().decode(TaskTemplateCatalog.self, from: data)
    } catch {
        fatalError("Failed to decode task_templates.json: \(error)")
    }
}

/// Convert a template days shorthand to the [Int] format TallyTask expects.
/// "daily" → [] (empty = daily), "weekdays" → [0,1,2,3,4], etc.
func templateDays(_ key: String) -> [Int] {
    switch key {
    case "daily":    return []
    case "weekdays": return [0, 1, 2, 3, 4]
    case "mwf":      return [0, 2, 4]
    case "weekends": return [5, 6]
    default:         return []
    }
}

/// Create a TallyTask from a TaskTemplate, ready to insert into ModelContext.
func taskFromTemplate(_ template: TaskTemplate) -> TallyTask {
    let taskType = TaskType(rawValue: template.type) ?? .check
    return TallyTask(
        name: template.name,
        type: taskType,
        target: template.target,
        unit: template.unit,
        days: templateDays(template.days),
        times: template.times
    )
}

/// Map a task type string to a theme-aware color for template card accents.
func typeColor(for type: String, colors: TallyColors) -> Color {
    switch type {
    case "check":   return colors.pos
    case "count":   return colors.accent
    case "timer":   return colors.warn
    case "numeric": return colors.neg
    case "yesno":   return colors.dim
    default:        return colors.dim2
    }
}
