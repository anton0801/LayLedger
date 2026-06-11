//
//  SettingsView.swift
//  LayLedger
//
//  Every control here has a real effect: units, currency, theme, categories,
//  backup and export — applied immediately and persisted.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var theme: ThemeManager

    @AppStorage("eggUnit") private var eggUnitRaw = EggUnit.eggs.rawValue
    @AppStorage("currencyCode") private var currencyCode = "USD"

    @State private var newCategory = ""
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var showToast = false

    private var eggUnitBinding: Binding<EggUnit> {
        Binding(get: { EggUnit(rawValue: eggUnitRaw) ?? .eggs },
                set: { eggUnitRaw = $0.rawValue })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                unitsCard
                currencyCard
                themeCard
                categoriesCard
                dataCard
                LLButton(title: "Save", icon: "checkmark") {
                    withAnimation { showToast = true }
                }
                aboutFooter
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Settings", displayMode: .inline)
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
        .toast(isShowing: $showToast, message: "Settings saved")
    }

    // MARK: Units

    private var unitsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                label("Egg units", icon: "oval.portrait.fill",
                      hint: "Show counts as individual eggs or dozens")
                LLSegmented(options: EggUnit.allCases, selection: eggUnitBinding) { $0.title }
                Text("Preview: \(formatEggs(18)) \(eggUnitLabel)")
                    .font(.captionM).foregroundColor(AppColor.textSecondary)
            }
        }
    }

    // MARK: Currency

    private var currencyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                label("Currency", icon: "dollarsign.circle.fill",
                      hint: "Used across sales, expenses and reports")
                Menu {
                    ForEach(currencyOptions, id: \.code) { option in
                        Button(option.label) { currencyCode = option.code }
                    }
                } label: {
                    HStack {
                        Text(currencyOptions.first { $0.code == currencyCode }?.label ?? currencyCode)
                            .font(.bodyM).foregroundColor(AppColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(AppColor.textDisabled)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(AppColor.bgSecondary).cornerRadius(12)
                }
                Text("Preview: \(formatMoney(24.5))")
                    .font(.captionM).foregroundColor(AppColor.textSecondary)
            }
        }
    }

    // MARK: Theme

    private var themeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                label("Appearance", icon: "paintbrush.fill",
                      hint: "Applies instantly across the whole app")
                LLSegmented(options: AppTheme.allCases, selection: $theme.theme) { $0.title }
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { t in
                        HStack(spacing: 5) {
                            Image(systemName: t.icon).font(.ll(11, .semibold))
                            Text(t.title).font(.ll(11, .medium))
                        }
                        .foregroundColor(theme.theme == t ? AppColor.accentActive : AppColor.textDisabled)
                    }
                }
            }
        }
    }

    // MARK: Categories

    private var categoriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                label("Categories", icon: "tag.fill", hint: "Tags for sales and expenses")
                HStack {
                    TextField("New category", text: $newCategory)
                        .font(.bodyM).foregroundColor(AppColor.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(AppColor.bgSecondary).cornerRadius(10)
                    Button { addCategory() } label: {
                        Image(systemName: "plus").font(.ll(16, .bold)).foregroundColor(AppColor.onAccent)
                            .frame(width: 44, height: 44).background(AppColor.accent).cornerRadius(12)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                FlowChips(items: store.categories) { category in
                    store.categories.removeAll { $0 == category }
                }
            }
        }
    }

    // MARK: Data

    private var dataCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                label("Data", icon: "externaldrive.fill", hint: "Backup or export your records")
                LLButton(title: "Backup (JSON)", icon: "arrow.up.doc.fill", kind: .secondary) { backup() }
                LLButton(title: "Export Data (CSV)", icon: "tablecells", kind: .secondary) { exportCSV() }
            }
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Text("Lay Ledger").font(.ll(13, .semibold)).foregroundColor(AppColor.textSecondary)
            Text("Smart poultry assistant • v1.0").font(.ll(11, .medium)).foregroundColor(AppColor.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: helpers

    private func label(_ title: String, icon: String, hint: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(AppColor.accent).font(.ll(16, .bold)).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cardTitle).foregroundColor(AppColor.textPrimary)
                Text(hint).font(.ll(11, .medium)).foregroundColor(AppColor.textSecondary)
            }
        }
    }

    private func addCategory() {
        let trimmed = newCategory.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !store.categories.contains(trimmed) else { return }
        withAnimation { store.categories.append(trimmed) }
        newCategory = ""
    }

    private func backup() {
        if let url = store.exportURL {
            shareItems = [url]
            showShare = true
        }
    }

    private func exportCSV() {
        var rows = ["Type,Title,Date,Amount,Category,Flock"]
        for r in store.records {
            let flock = store.flock(r.flockId)?.name ?? ""
            rows.append("\(r.category.title),\"\(r.title)\",\(shortDate(r.date)),\(r.amount),\(r.tag ?? ""),\(flock)")
        }
        for e in store.eggEntries {
            let flock = store.flock(e.flockId)?.name ?? ""
            rows.append("Eggs,\(e.eggsCollected) collected,\(shortDate(e.date)),,,\(flock)")
        }
        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LayLedger-Export.csv")
        try? csv.data(using: .utf8)?.write(to: url, options: .atomic)
        shareItems = [url]
        showShare = true
    }
}

// MARK: - Flow chips (wrapping)

struct FlowChips: View {
    let items: [String]
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows(), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        HStack(spacing: 6) {
                            Text(item).font(.ll(13, .semibold)).foregroundColor(AppColor.textPrimary)
                            Button { onDelete(item) } label: {
                                Image(systemName: "xmark.circle.fill").font(.ll(12, .bold))
                                    .foregroundColor(AppColor.textDisabled)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(AppColor.depth).clipShape(Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Simple greedy wrap: 3 chips per row.
    private func rows() -> [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        for item in items {
            current.append(item)
            if current.count == 3 { result.append(current); current = [] }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
