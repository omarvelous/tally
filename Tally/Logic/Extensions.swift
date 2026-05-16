//
//  Extensions.swift
//  Tally
//
//  Shared extensions used across the app.

import Foundation

// Required for .sheet(item:) with String-based IDs (e.g., logTaskId, editingTaskId)
extension String: @retroactive Identifiable {
    public var id: String { self }
}
