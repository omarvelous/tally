//
//  TallySchema.swift
//  Tally
//
//  Schema versioning for safe SwiftData migrations.
//  V1: original local-only models (TallyTask, LogEntry, TallySettings)
//  V2: adds Supabase-mirrored models alongside V1 (both coexist during migration)

import SwiftData

enum TallySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TallyTask.self, LogEntry.self, TallySettings.self]
    }
}

enum TallySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        // V1 models kept for data migration; new Supabase-mirrored models added
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
        [TallySchemaV1.self, TallySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // V1→V2: lightweight — only adds new tables, no column changes to existing models
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: TallySchemaV1.self,
        toVersion: TallySchemaV2.self
    )
}
