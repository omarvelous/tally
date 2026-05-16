//
//  ManageTasksView.swift
//  Tally
//
//  Bulk task admin: edit, archive/restore, delete.

import SwiftUI
import SwiftData

struct ManageTasksView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTasks: [TallyTask]

    @State private var editingTaskId: String?
    @State private var deleteTarget: TallyTask?

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "\(allTasks.count) TOTAL")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text("Manage")
                            .font(TallyFont.heading(28, weight: .medium))
                            .foregroundStyle(c.text)
                    }
                    .padding(.bottom, 16)

                    ForEach(allTasks, id: \.id) { task in
                        let sched = describeSchedule(task)
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.name)
                                    .font(TallyFont.heading(14, weight: .medium))
                                    .foregroundStyle(task.archived ? c.dim : c.text)
                                Text(verbatim: "\(sched.days.uppercased()) · \(task.type.rawValue.uppercased())\(task.archived ? " · ARCHIVED" : "")")
                                    .font(TallyFont.mono(10))
                                    .foregroundStyle(c.dim)
                            }
                            Spacer()
                            Button("EDIT") {
                                editingTaskId = task.id
                            }
                            .font(TallyFont.mono(10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(c.accent)

                            Button(task.archived ? "RESTORE" : "ARCHIVE") {
                                task.archived.toggle()
                            }
                            .font(TallyFont.mono(10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(c.dim)

                            Button("DEL") {
                                deleteTarget = task
                            }
                            .font(TallyFont.mono(10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(c.neg)
                        }
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(c.rule).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationTitle("Manage tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $editingTaskId) { taskId in
            TaskFormView(taskId: taskId)
        }
        .confirmationDialog("Delete \"\(deleteTarget?.name ?? "")\"?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Delete task & all history", role: .destructive) {
                if let task = deleteTarget {
                    deleteTask(task)
                    deleteTarget = nil
                }
            }
        }
    }

    private func deleteTask(_ task: TallyTask) {
        let taskId = task.id
        let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.taskId == taskId })
        if let entries = try? modelContext.fetch(descriptor) {
            for entry in entries { modelContext.delete(entry) }
        }
        modelContext.delete(task)
    }
}