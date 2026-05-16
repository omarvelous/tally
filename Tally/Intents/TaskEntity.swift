//
//  TaskEntity.swift
//  Tally
//
//  AppEntity wrapping TallyTask so Siri can resolve task names.

import AppIntents
import SwiftData

struct TaskEntity: AppEntity {
    static var defaultQuery = TaskEntityQuery()
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task")

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        let tasks = try await fetchAllTasks()
        return tasks.filter { identifiers.contains($0.id) }
            .map { TaskEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        let tasks = try await fetchAllTasks()
        return tasks.filter { !$0.archived }
            .map { TaskEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    private func fetchAllTasks() throws -> [TallyTask] {
        let container = try ModelContainer(for: TallyTask.self, LogEntry.self, TallySettings.self)
        let context = container.mainContext
        return try context.fetch(FetchDescriptor<TallyTask>())
    }
}

extension TaskEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [TaskEntity] {
        let tasks = try await fetchAllTasks()
        let lowered = string.lowercased()
        return tasks
            .filter { !$0.archived && $0.name.lowercased().contains(lowered) }
            .map { TaskEntity(id: $0.id, name: $0.name) }
    }
}
