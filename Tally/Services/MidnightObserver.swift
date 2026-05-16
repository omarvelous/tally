//
//  MidnightObserver.swift
//  Tally
//
//  Detects day rollover while the app is in the foreground.
//  Views observe `currentDateKey` to refresh when the date changes.

import Foundation
import SwiftUI
import Combine

@Observable
final class MidnightObserver {
    var currentDateKey: String

    private var timer: AnyCancellable?
    private var notificationObserver: Any?

    init() {
        self.currentDateKey = localDateKey(Date())
        startObserving()
    }

    deinit {
        timer?.cancel()
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func startObserving() {
        // Check every 30 seconds if the date has changed
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkDateChange()
            }

        // Also listen for significant time changes (DST, timezone, manual clock change)
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkDateChange()
        }
    }

    private func checkDateChange() {
        let newKey = localDateKey(Date())
        if newKey != currentDateKey {
            currentDateKey = newKey
        }
    }
}

// MARK: - Environment key

private struct MidnightObserverKey: EnvironmentKey {
    static let defaultValue = MidnightObserver()
}

extension EnvironmentValues {
    var midnightObserver: MidnightObserver {
        get { self[MidnightObserverKey.self] }
        set { self[MidnightObserverKey.self] = newValue }
    }
}
