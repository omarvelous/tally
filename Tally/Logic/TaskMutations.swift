//
//  TaskMutations.swift
//  Tally
//
//  Shared mutation functions. Single source of truth for cascade operations.

import Foundation
import SwiftData

/// Delete a task and all its log entries. Single cascade delete codepath.
func deleteTaskAndEntries(taskId: String, context: ModelContext) {
    let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.taskId == taskId })
    if let entries = try? context.fetch(descriptor) {
        for entry in entries {
            context.delete(entry)
        }
    }
    let taskDescriptor = FetchDescriptor<TallyTask>(predicate: #Predicate { $0.id == taskId })
    if let task = try? context.fetch(taskDescriptor).first {
        context.delete(task)
    }
}
