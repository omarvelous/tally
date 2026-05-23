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
    @State private var appPhase: AppPhase = .loading

    enum AppPhase {
        case loading
        case onboarding
        case ready
    }

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
                    switch appPhase {
                    case .loading:
                        ProgressView("Loading habits...")
                            .environment(syncEngine)
                            .task { await onSignedIn() }
                    case .onboarding:
                        OnboardingScreen {
                            Task { await onOnboardingComplete() }
                        }
                        .environment(syncEngine)
                    case .ready:
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

        guard let userId = authService.userId else {
            print("[TallyApp] no userId after sign-in — skipping to ready")
            appPhase = .ready
            return
        }

        await syncEngine.pullUserData(context: context, profileId: userId)

        // Check if user has any habits — if not, show onboarding
        let pid = userId
        let userHabits = (try? context.fetch(
            FetchDescriptor<UserHabit>(predicate: #Predicate { $0.profileId == pid })
        )) ?? []

        print("[TallyApp] userId=\(userId), userHabits=\(userHabits.count)")

        if userHabits.isEmpty {
            appPhase = .onboarding
        } else {
            // Generate today's habit_days locally (idempotent) + push to Supabase
            HabitDayGenerator.generateForDate(Date(), profileId: userId, context: context)
            await syncEngine.pushHabitDaysForDate(Date(), profileId: userId, context: context)
            appPhase = .ready
        }

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
        withAnimation { appPhase = .ready }
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
