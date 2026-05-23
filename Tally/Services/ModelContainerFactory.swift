//
//  ModelContainerFactory.swift
//  Tally
//
//  Shared ModelContainer configuration used by the app, widgets, and intents.
//  Uses App Group container so the widget extension can read the same database.

import Foundation
import SwiftData

enum ModelContainerFactory {
    static let appGroupID = "group.omarvelous.Tally"

    static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: TallySchemaV2.self)

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
                .appending(path: "Tally.store")
            config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: TallyMigrationPlan.self,
            configurations: [config]
        )
    }
}
