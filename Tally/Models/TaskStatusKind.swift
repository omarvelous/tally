//
//  TaskStatusKind.swift
//  Tally
//
//  Status enum used by views to render habit completion state.

import Foundation

enum TaskStatusKind: String, Sendable {
    case done
    case partial
    case overdue
    case due
    case off
}
