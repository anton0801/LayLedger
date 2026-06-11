//
//  LedgerViews.swift
//  LayLedger
//
//  Sales, Expenses, Add Record form and Record Details.
//

import SwiftUI

// MARK: - Shared row

struct RecordRow: View {
    @EnvironmentObject var store: DataStore
    let record: LedgerRecord

    var body: some View {
        Card {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(record.category.color.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: record.category.icon).foregroundColor(record.category.color)
                        .font(.ll(18, .bold))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title).font(.ll(16, .semibold)).foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(shortDate(record.date)).font(.captionM).foregroundColor(AppColor.textSecondary)
                        if let tag = record.tag, !tag.isEmpty {
                            Text("• \(tag)").font(.captionM).foregroundColor(AppColor.textSecondary)
                        }
                    }
                }
                Spacer()
                Text((record.category.sign < 0 ? "-" : record.category == .sale ? "+" : "") + formatMoney(record.amount))
                    .font(.ll(16, .bold))
                    .foregroundColor(record.category == .expense ? AppColor.problem :
                                        record.category == .sale ? AppColor.good : AppColor.textPrimary)
            }
        }
    }
}

// MARK: - Sales

struct SalesView: View {
    @EnvironmentObject var store: DataStore
    @State private var showAdd = false

    var body: some View {
        LedgerList(category: .sale, title: "Sales",
                   total: store.totalSales(), totalLabel: "Total income",
                   showAdd: $showAdd)
            .sheet(isPresented: $showAdd) { AddRecordView(presetCategory: .sale).environmentObject(store) }
    }
}

// MARK: - Expenses

struct ExpensesView: View {
    @EnvironmentObject var store: DataStore
    @State private var showAdd = false

    var body: some View {
        LedgerList(category: .expense, title: "Expenses",
                   total: store.totalExpenses(), totalLabel: "Total spent",
                   showAdd: $showAdd)
            .sheet(isPresented: $showAdd) { AddRecordView(presetCategory: .expense).environmentObject(store) }
    }
}

private struct LedgerList: View {
    @EnvironmentObject var store: DataStore
    let category: RecordCategory
    let title: String
    let total: Double
    let totalLabel: String
    @Binding var showAdd: Bool

    var body: some View {
        let items = store.records(category)
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(totalLabel).font(.captionM).foregroundColor(AppColor.textSecondary)
                            Text(formatMoney(total)).font(.ll(30, .bold))
                                .foregroundColor(category == .sale ? AppColor.good : AppColor.problem)
                        }
                        Spacer()
                        Image(systemName: category.icon).font(.ll(34, .bold))
                            .foregroundColor(category.color.opacity(0.5))
                    }
                }

                if items.isEmpty {
                    EmptyStateView(icon: category.icon, title: "No \(title.lowercased()) yet",
                                   message: "Tap + to add your first \(category.title.lowercased()).",
                                   actionTitle: "Add \(category.title)") { showAdd = true }
                } else {
                    ForEach(items) { record in
                        NavigationLink(destination: RecordDetailsView(record: record)) {
                            RecordRow(record: record).environmentObject(store)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle(title, displayMode: .inline)
        .navigationBarItems(trailing: Button { showAdd = true } label: {
            Image(systemName: "plus").font(.ll(17, .semibold)).foregroundColor(AppColor.accentActive)
        })
    }
}

// MARK: - Add / Edit / Duplicate Record

struct AddRecordView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode

    var presetCategory: RecordCategory? = nil
    var existing: LedgerRecord? = nil
    var duplicateFrom: LedgerRecord? = nil

    @State private var title = ""
    @State private var flockId: UUID? = nil
    @State private var date = Date()
    @State private var category: RecordCategory = .expense
    @State private var amount = ""
    @State private var comment = ""
    @State private var tag: String? = nil
    @State private var photo: Data? = nil
    @State private var showPicker = false
    @State private var showError = false
    @State private var showToast = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category").font(.captionM).foregroundColor(AppColor.textSecondary)
                            LLSegmented(options: RecordCategory.allCases, selection: $category) { $0.title }
                        }
                    }
                    LabeledTextField(label: "Title", placeholder: "e.g. Egg sales — dozen x6",
                                     text: $title, icon: "tag.fill")
                    if category != .note {
                        LabeledNumberField(label: "Amount", placeholder: "0.00", value: $amount,
                                           icon: "dollarsign.circle", unit: AppSettings.currencyCode)
                    }
                    flockPicker
                    tagPicker
                    Card(padding: 0) {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .accentColor(AppColor.accentActive).foregroundColor(AppColor.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                    }
                    LabeledMultilineField(label: "Comment", text: $comment)
                    photoButton

                    HStack(spacing: 10) {
                        LLButton(title: "Add Another", icon: "plus", kind: .secondary) { save(keepOpen: true) }
                        LLButton(title: "Save", icon: "checkmark") { save(keepOpen: false) }
                    }
                    if showError {
                        Text("Enter a title\(category == .note ? "" : " and amount").")
                            .font(.captionM).foregroundColor(AppColor.problem)
                    }
                }
                .padding(18)
            }
            .background(AppColor.bgGradient.ignoresSafeArea())
            .navigationBarTitle(navTitle, displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .onAppear(perform: prefill)
            .sheet(isPresented: $showPicker) { PhotoPicker(imageData: $photo) }
            .toast(isShowing: $showToast, message: "Saved")
        }
    }

    private var navTitle: String {
        if existing != nil { return "Edit Record" }
        if duplicateFrom != nil { return "Duplicate Record" }
        return "Add Record"
    }

    private var flockPicker: some View {
        Card {
            HStack {
                Text("Flock").font(.bodyM).foregroundColor(AppColor.textSecondary)
                Spacer()
                Menu {
                    Button("No flock") { flockId = nil }
                    ForEach(store.activeFlocks) { f in Button(f.name) { flockId = f.id } }
                } label: {
                    HStack(spacing: 6) {
                        Text(store.flock(flockId)?.name ?? "No flock")
                            .font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary)
                        Image(systemName: "chevron.up.chevron.down").font(.ll(11, .semibold))
                            .foregroundColor(AppColor.textDisabled)
                    }
                }
            }
        }
    }

    private var tagPicker: some View {
        Card {
            HStack {
                Text("Tag").font(.bodyM).foregroundColor(AppColor.textSecondary)
                Spacer()
                Menu {
                    Button("None") { tag = nil }
                    ForEach(store.categories, id: \.self) { c in Button(c) { tag = c } }
                } label: {
                    HStack(spacing: 6) {
                        Text(tag ?? "None").font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary)
                        Image(systemName: "chevron.up.chevron.down").font(.ll(11, .semibold))
                            .foregroundColor(AppColor.textDisabled)
                    }
                }
            }
        }
    }

    private var photoButton: some View {
        Button { showPicker = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(AppColor.bgSecondary).frame(height: 130)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColor.border, lineWidth: 1))
                if let image = Image(data: photo) {
                    image.resizable().scaledToFill().frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus").font(.ll(22, .bold)).foregroundColor(AppColor.accent)
                        Text("Attach photo").font(.captionM).foregroundColor(AppColor.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func prefill() {
        if let r = existing ?? duplicateFrom {
            title = r.title; flockId = r.flockId; date = r.date; category = r.category
            amount = r.amount == 0 ? "" : String(r.amount); comment = r.comment; tag = r.tag; photo = r.photo
        } else if let c = presetCategory {
            category = c
        }
    }

    private func save(keepOpen: Bool) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let value = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard !trimmed.isEmpty, (category == .note || value > 0) else {
            withAnimation { showError = true }; return
        }
        if var r = existing {
            r.title = trimmed; r.flockId = flockId; r.date = date; r.category = category
            r.amount = value; r.comment = comment; r.tag = tag; r.photo = photo
            store.updateRecord(r)
            dismiss(); return
        }
        var r = LedgerRecord(title: trimmed)
        r.flockId = flockId; r.date = date; r.category = category
        r.amount = value; r.comment = comment; r.tag = tag; r.photo = photo
        store.addRecord(r)
        if keepOpen {
            title = ""; amount = ""; comment = ""; photo = nil
            withAnimation { showToast = true }
        } else {
            dismiss()
        }
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}

// MARK: - Record Details

struct RecordDetailsView: View {
    @EnvironmentObject var store: DataStore
    let record: LedgerRecord

    @State private var showEdit = false
    @State private var showDuplicate = false
    @State private var taskAdded = false

    private var current: LedgerRecord { store.records.first { $0.id == record.id } ?? record }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            TagChip(text: current.category.title, color: current.category.color, filled: true)
                            Spacer()
                            Text((current.category.sign < 0 ? "-" : current.category == .sale ? "+" : "") + formatMoney(current.amount))
                                .font(.ll(26, .bold))
                                .foregroundColor(current.category == .expense ? AppColor.problem :
                                                    current.category == .sale ? AppColor.good : AppColor.textPrimary)
                        }
                        Text(current.title).font(.ll(22, .bold)).foregroundColor(AppColor.textPrimary)
                        detailRow(icon: "calendar", label: "Date", value: mediumDate(current.date))
                        if let f = store.flock(current.flockId) {
                            detailRow(icon: "bird.fill", label: "Flock", value: f.name)
                        }
                        if let tag = current.tag, !tag.isEmpty {
                            detailRow(icon: "tag.fill", label: "Tag", value: tag)
                        }
                        if !current.comment.isEmpty {
                            detailRow(icon: "text.alignleft", label: "Notes", value: current.comment)
                        }
                    }
                }

                if let image = Image(data: current.photo) {
                    image.resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColor.border, lineWidth: 1))
                }

                LLButton(title: "Edit", icon: "pencil") { showEdit = true }
                HStack(spacing: 10) {
                    LLButton(title: "Duplicate", icon: "plus.square.on.square", kind: .secondary) { showDuplicate = true }
                    LLButton(title: taskAdded ? "Task added" : "Create Task",
                             icon: taskAdded ? "checkmark" : "checklist",
                             kind: taskAdded ? .success : .secondary) { createTask() }
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Details", displayMode: .inline)
        .sheet(isPresented: $showEdit) { AddRecordView(existing: current).environmentObject(store) }
        .sheet(isPresented: $showDuplicate) { AddRecordView(duplicateFrom: current).environmentObject(store) }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.ll(14, .semibold)).foregroundColor(AppColor.accentActive)
                .frame(width: 22)
            Text(label).font(.bodyM).foregroundColor(AppColor.textSecondary)
            Spacer()
            Text(value).font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func createTask() {
        let task = TaskItem(title: "Follow up: \(current.title)",
                            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        store.addTask(task)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { taskAdded = true }
    }
}
