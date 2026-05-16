//
//  ModelContainerFactory.swift
//  Tally
//
//  Shared ModelContainer configuration used by the app, widgets, and intents.
//  Ensures all targets use identical CloudKit + migration settings.

import SwiftData

enum ModelContainerFactory {
    static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: TallySchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: TallyMigrationPlan.self,
            configurations: [config]
        )
    }
}
