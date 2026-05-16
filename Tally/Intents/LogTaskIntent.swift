//
//  LogTaskIntent.swift
//  Tally
//
//  AppIntent: "Log 20 pushups in Tally"

import AppIntents
import SwiftData

struct LogTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Task"
    static var description = IntentDescription("Log a value against a Tally task.")
    static var openAppWhenRun = false

    @Parameter(title: "Task")
    var task: TaskEntity

    @Parameter(title: "Value")
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: TallyTask.self, LogEntry.self, TallySettings.self)
        let context = container.mainContext

        // Find the task
        let taskId = task.id
        let descriptor = FetchDescriptor<TallyTask>(predicate: #Predicate { $0.id == taskId })
        guard let tallyTask = try context.fetch(descriptor).first else {
            return .result(dialog: "Couldn't find task \"\(task.name)\".")
        }

        // Create the log entry
        let now = Date()
        let entry = LogEntry(
            taskId: tallyTask.id,
            date: localDateKey(now),
            time: localTimeKey(now),
            value: value
        )
        context.insert(entry)
        try context.save()

        let unitStr = tallyTask.unit ?? ""
        return .result(dialog: "Logged \(Int(value)) \(unitStr) for \(tallyTask.name).")
    }
}
