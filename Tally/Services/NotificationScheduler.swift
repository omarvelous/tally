//
//  NotificationScheduler.swift
//  Tally
//
//  Schedules local notifications per task time/day with optional nag follow-ups.
//  Respects quiet hours from TallySettings.

import Foundation
import UserNotifications
import SwiftData

@Observable
final class NotificationScheduler {
    private(set) var isAuthorized = false

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
        } catch {
            await MainActor.run { isAuthorized = false }
        }
    }

    // MARK: - Schedule all

    /// Reschedule all notifications from scratch. Call on app launch and after any task edit.
    func rescheduleAll(tasks: [TallyTask], quietHoursEnabled: Bool, quietStart: String, quietEnd: String) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let activeTasks = tasks.filter { !$0.archived }

        for task in activeTasks {
            guard task.notifPing else { continue }
            guard task.times.first != "all-day" else { continue }

            let scheduledDays = task.days.isEmpty ? Array(0...6) : task.days

            for time in task.times {
                let hhmm = parseHHMM(time)

                // Skip if in quiet hours
                if quietHoursEnabled && isInQuietHours(hour: hhmm.h, minute: hhmm.m, start: quietStart, end: quietEnd) {
                    continue
                }

                for dow in scheduledDays {
                    // Primary notification at task time
                    let id = "tally-\(task.id)-\(dow)-\(time)"
                    let content = UNMutableNotificationContent()
                    content.title = task.name
                    content.body = notificationBody(for: task)
                    if task.notifSound {
                        content.sound = .default
                    }

                    var dateComponents = DateComponents()
                    dateComponents.hour = hhmm.h
                    dateComponents.minute = hhmm.m
                    dateComponents.weekday = appleWeekday(from: dow)

                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    center.add(request)

                    // Nag notification (+15 min) if enabled
                    if task.notifNag {
                        let nagMins = hhmm.mins + 15
                        let nagH = nagMins / 60
                        let nagM = nagMins % 60

                        if nagH < 24 && !(quietHoursEnabled && isInQuietHours(hour: nagH, minute: nagM, start: quietStart, end: quietEnd)) {
                            let nagId = "tally-nag-\(task.id)-\(dow)-\(time)"
                            let nagContent = UNMutableNotificationContent()
                            nagContent.title = "Still pending: \(task.name)"
                            nagContent.body = "You have 15 minutes overdue on this task."
                            if task.notifSound {
                                nagContent.sound = .default
                            }

                            var nagComponents = DateComponents()
                            nagComponents.hour = nagH
                            nagComponents.minute = nagM
                            nagComponents.weekday = appleWeekday(from: dow)

                            let nagTrigger = UNCalendarNotificationTrigger(dateMatching: nagComponents, repeats: true)
                            let nagRequest = UNNotificationRequest(identifier: nagId, content: nagContent, trigger: nagTrigger)
                            center.add(nagRequest)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Convert our Mon=0..Sun=6 to Apple's Sun=1..Sat=7
    private func appleWeekday(from dow: Int) -> Int {
        // dow: 0=Mon, 1=Tue, ..., 5=Sat, 6=Sun
        // Apple: 1=Sun, 2=Mon, ..., 7=Sat
        return dow == 6 ? 1 : dow + 2
    }

    private func notificationBody(for task: TallyTask) -> String {
        switch task.type {
        case .check: return "Time to check off \(task.name)."
        case .count: return "Log toward your \(Int(task.target ?? 0)) \(task.unit ?? "") goal."
        case .timer: return "Start your \(Int(task.target ?? 0)) min session."
        case .numeric: return "Record today's \(task.unit ?? "reading")."
        case .yesno: return "Answer today's question."
        }
    }

    private func isInQuietHours(hour: Int, minute: Int, start: String, end: String) -> Bool {
        let current = hour * 60 + minute
        let startMins = parseHHMM(start).mins
        let endMins = parseHHMM(end).mins

        if startMins <= endMins {
            // e.g., 08:00 - 20:00 (same day)
            return current >= startMins && current < endMins
        } else {
            // e.g., 22:00 - 06:30 (spans midnight)
            return current >= startMins || current < endMins
        }
    }
}
