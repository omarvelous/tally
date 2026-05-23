//
//  TallyApp.swift
//  Tally
//
//  Created by Omar Johnson on 5/15/26.
//

import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    @State private var notificationScheduler = NotificationScheduler()
    @State private var midnightObserver = MidnightObserver()
    @State private var authService = AuthService()
    @State private var syncEngine = SyncEngine()
    @State private var needsOnboarding = false
    @State private var catalogReady = false

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.create()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    ProgressView()
                } else if authService.isSignedIn {
                    if !catalogReady {
                        ProgressView("Loading habits...")
                            .environment(syncEngine)
                            .task { await onSignedIn() }
                    } else if needsOnboarding {
                        OnboardingScreen {
                            Task { await onOnboardingComplete() }
                        }
                        .environment(syncEngine)
                    } else {
                        ContentView()
                            .environment(notificationScheduler)
                            .environment(midnightObserver)
                            .environment(syncEngine)
                    }
                } else {
                    SignInView()
                }
            }
            .environment(authService)
            .task {
                await authService.initialize()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func onSignedIn() async {
        let context = sharedModelContainer.mainContext

        // Drain any pending sync items from previous sessions (offline writes)
        await syncEngine.drainPendingSync(context: context)

        // Pull global catalog + user data from Supabase
        await syncEngine.pullCatalog(context: context)
        if let userId = authService.userId {
            await syncEngine.pullUserData(context: context, profileId: userId)

            // Check if user has any habits — if not, show onboarding
            let pid = userId
            let userHabits = (try? context.fetch(
                FetchDescriptor<UserHabit>(predicate: #Predicate { $0.profileId == pid })
            )) ?? []

            if userHabits.isEmpty {
                needsOnboarding = true
            } else {
                // Generate today's habit_days locally (idempotent) + push to Supabase
                HabitDayGenerator.generateForDate(Date(), profileId: userId, context: context)
                await syncEngine.pushHabitDaysForDate(Date(), profileId: userId, context: context)
            }
        }

        catalogReady = true

        // Schedule notifications
        await notificationScheduler.requestPermission()
        scheduleNotifications()
    }

    @MainActor
    private func onOnboardingComplete() async {
        let context = sharedModelContainer.mainContext
        if let userId = authService.userId {
            HabitDayGenerator.generateForDate(Date(), profileId: userId, context: context)
            await syncEngine.pushHabitDaysForDate(Date(), profileId: userId, context: context)
        }
        withAnimation { needsOnboarding = false }
    }

    @MainActor
    private func scheduleNotifications() {
        let context = sharedModelContainer.mainContext
        let tasks = (try? context.fetch(FetchDescriptor<TallyTask>())) ?? []
        let settings = (try? context.fetch(FetchDescriptor<TallySettings>()))?.first

        notificationScheduler.rescheduleAll(
            tasks: tasks,
            quietHoursEnabled: settings?.quietHoursEnabled ?? false,
            quietStart: settings?.quietHoursStart ?? "22:00",
            quietEnd: settings?.quietHoursEnd ?? "06:30"
        )
    }
}
