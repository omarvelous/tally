//
//  TallySchema.swift
//  Tally
//
//  Single schema definition for active development.
//  Versioned migration will be added before first production release.

import SwiftData

enum TallySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TallyTask.self, LogEntry.self, TallySettings.self,
            Category.self, Habit.self, UserHabit.self,
            UserHabitSchedule.self, HabitDay.self, DaySummary.self,
            Profile.self, UserPreferences.self, PendingSync.self,
        ]
    }
}

enum TallyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TallySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
