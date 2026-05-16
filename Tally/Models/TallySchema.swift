//
//  TallySchema.swift
//  Tally
//
//  Schema versioning for safe SwiftData migrations.
//  Snapshot V1 BEFORE first release so future versions can migrate.

import SwiftData

enum TallySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TallyTask.self, LogEntry.self, TallySettings.self]
    }
}

enum TallyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TallySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the baseline.
        // Future: add MigrationStage.lightweight(fromVersion:toVersion:) here.
        []
    }
}
