//
//  OnboardingView.swift
//  Tally
//
//  First-run welcome: "One rule. 100% the day."

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]
    @Query private var settings: [TallySettings]

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()
        let streak = streakFor(tasks: tasks, entries: allEntries, now: now)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("TALLY · v1.0")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)

                    // Hero
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("One rule.")
                                .font(TallyFont.heading(48, weight: .medium))
                                .foregroundStyle(c.text)
                            Text("100% the day.")
                                .font(TallyFont.heading(48, weight: .medium))
                                .foregroundStyle(c.accent)
                        }
                        Text("Schedule tasks at times that matter. Hit every one — earn the day. Miss any — break the chain.")
                            .font(TallyFont.body(15))
                            .foregroundStyle(c.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // 30-day strip
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR LAST 30 DAYS")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)

                        HStack(spacing: 2) {
                            ForEach(Array(streak.history.suffix(30).enumerated()), id: \.offset) { _, day in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(day.total == 0 ? c.bg3 : day.pct >= 1 ? c.accent : day.pct > 0 ? c.accentSoft : c.bg3)
                            }
                        }
                        .frame(height: 30)

                        HStack {
                            Text("—30D")
                                .font(TallyFont.mono(10))
                                .foregroundStyle(c.dim)
                            Spacer()
                            Text(verbatim: "STREAK · \(streak.current)D")
                                .font(TallyFont.mono(10))
                                .foregroundStyle(c.accent)
                        }
                    }

                    // Features
                    VStack(spacing: 0) {
                        featureRow(num: "01", title: "SCHEDULE", desc: "Pick days, set times", c: c)
                        featureRow(num: "02", title: "LOG ITERATIVELY", desc: "Add sets toward a daily goal", c: c)
                        featureRow(num: "03", title: "GRACE TILL MIDNIGHT", desc: "Catch up before the day flips", c: c)
                        featureRow(num: "04", title: "TRACK EVERYTHING", desc: "Every task, every day", c: c)
                    }

                    // CTA
                    Button {
                        markOnboarded()
                        dismiss()
                    } label: {
                        Text("Start tallying →")
                            .font(TallyFont.heading(14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(c.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(c.bg)
        }
    }

    private func featureRow(num: String, title: String, desc: String, c: TallyColors) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: num)
                .font(TallyFont.mono(11))
                .foregroundStyle(c.dim)
                .frame(width: 24)
            Text(verbatim: title)
                .font(TallyFont.heading(13, weight: .medium))
                .foregroundStyle(c.text)
                .frame(width: 130, alignment: .leading)
            Text(desc)
                .font(TallyFont.body(13))
                .foregroundStyle(c.dim)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(c.rule).frame(height: 1)
        }
    }

    private func markOnboarded() {
        if let s = settings.first {
            s.hasOnboarded = true
        } else {
            let s = TallySettings(hasOnboarded: true)
            modelContext.insert(s)
        }
    }
}
