//
//  TaskTemplateCatalog.swift
//  Tally
//
//  Public Codable models for the JSON-driven task template catalog.
//  Decoded from task_templates.json bundled in app resources.

import Foundation

struct TaskTemplateCatalog: Codable, Sendable {
    let categories: [TemplateCategory]
    let units: [String]
    let defaultUnits: [String: String]
    let popular: [String]
    let templates: [TaskTemplate]
}

struct TemplateCategory: Codable, Identifiable, Sendable {
    let id: String
    let name: String
}

struct TaskTemplate: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let category: String
    let type: String
    let target: Double?
    let unit: String?
    let allowedUnits: [String]?
    let days: String
    let times: [String]
}
