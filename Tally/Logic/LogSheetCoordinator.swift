//
//  LogSheetCoordinator.swift
//  Tally
//
//  App-level state for the LogSheet modal. Any screen can open/close it.

import SwiftUI

@Observable
final class LogSheetCoordinator {
    var logTaskId: String?

    func open(_ taskId: String) {
        logTaskId = taskId
    }

    func close() {
        logTaskId = nil
    }
}
