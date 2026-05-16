//
//  TaskType.swift
//  Tally
//

import Foundation

enum TaskType: String, Codable, CaseIterable, Sendable {
    case check
    case count
    case timer
    case numeric
    case yesno
}
