//
//  TasksView.swift
//  LayLedger
//
//  Task list with filters, add and mark-done — all persisted.
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: DataStore
    @State private var filter: TaskFilter = .all
    @State private var showAdd = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                LLSegmented(options: TaskFilter.allCases, selection: $filter) { $0.title }

                let items = store.tasks(filter)
                if items.isEmpty {
                    EmptyStateView(icon: "checkmark.circle", title: "Nothing here",
                                   message: filter == .done ? "No completed tasks yet." : "You're all caught up.",
                                   actionTitle: "Add Task") { showAdd = true }
                } else {
                    ForEach(items) { task in
                        taskRow(task)
                    }
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Tasks", displayMode: .inline)
        .navigationBarItems(trailing: Button { showAdd = true } label: {
            Image(systemName: "plus").font(.ll(17, .semibold)).foregroundColor(AppColor.accentActive)
        })
        .sheet(isPresented: $showAdd) { AddTaskView().environmentObject(store) }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        Card {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { store.toggleTask(task) }
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.ll(24, .bold))
                        .foregroundColor(task.isDone ? AppColor.good : AppColor.textDisabled)
                }
                .buttonStyle(PressableButtonStyle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.ll(16, .semibold))
                        .foregroundColor(task.isDone ? AppColor.textDisabled : AppColor.textPrimary)
                        .strikethrough(task.isDone, color: AppColor.textDisabled)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.ll(11, .semibold))
                        Text(dueLabel(task)).font(.captionM)
                    }
                    .foregroundColor(dueColor(task))
                }
                Spacer()
                Menu {
                    Button { store.deleteTask(task) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.ll(16, .bold))
                        .foregroundColor(AppColor.textSecondary).frame(width: 28, height: 28)
                }
            }
        }
    }

    private func dueLabel(_ task: TaskItem) -> String {
        if Calendar.current.isDateInToday(task.dueDate) { return "Today" }
        return mediumDate(task.dueDate)
    }
    private func dueColor(_ task: TaskItem) -> Color {
        if task.isDone { return AppColor.textDisabled }
        if task.dueDate < Calendar.current.startOfDay(for: Date()) { return AppColor.problem }
        if Calendar.current.isDateInToday(task.dueDate) { return AppColor.accentActive }
        return AppColor.textSecondary
    }
}

struct AddTaskView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var title = ""
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var showError = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    LabeledTextField(label: "Task", placeholder: "e.g. Buy oyster shell",
                                     text: $title, icon: "checklist")
                    Card(padding: 0) {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                            .accentColor(AppColor.accentActive).foregroundColor(AppColor.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                    }
                    LabeledMultilineField(label: "Notes", text: $notes)
                    LLButton(title: "Add Task", icon: "checkmark") { save() }
                    if showError {
                        Text("Enter a task title.").font(.captionM).foregroundColor(AppColor.problem)
                    }
                }
                .padding(18)
            }
            .background(AppColor.bgGradient.ignoresSafeArea())
            .navigationBarTitle("Add Task", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { showError = true }; return }
        var task = TaskItem(title: trimmed, dueDate: dueDate)
        task.notes = notes
        store.addTask(task)
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
