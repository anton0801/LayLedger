//
//  HistoryView.swift
//  LayLedger
//
//  Unified timeline of logged eggs, sales and expenses with filtering.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: DataStore

    enum HFilter: String, CaseIterable, Identifiable {
        case all, logged, sold, spent
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }
    @State private var filter: HFilter = .all

    private struct HItem: Identifiable {
        let id = UUID()
        let date: Date
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let amount: String?
        let record: LedgerRecord?
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                LLSegmented(options: HFilter.allCases, selection: $filter) { $0.title }

                let items = buildItems()
                if items.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "No history",
                                   message: "Logged eggs, sales and expenses will appear here.") { }
                } else {
                    ForEach(items) { item in
                        if let record = item.record {
                            NavigationLink(destination: RecordDetailsView(record: record)) {
                                row(item)
                            }
                            .buttonStyle(PressableButtonStyle())
                        } else {
                            row(item)
                        }
                    }
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("History", displayMode: .inline)
    }

    private func row(_ item: HItem) -> some View {
        Card {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(item.color.opacity(0.16)).frame(width: 42, height: 42)
                    Image(systemName: item.icon).foregroundColor(item.color).font(.ll(17, .bold))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary).lineLimit(1)
                    Text(item.subtitle).font(.captionM).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
                if let amount = item.amount {
                    Text(amount).font(.ll(15, .bold)).foregroundColor(item.color)
                }
            }
        }
    }

    private func buildItems() -> [HItem] {
        var items: [HItem] = []

        if filter == .all || filter == .logged {
            for entry in store.eggEntries {
                let flockName = store.flock(entry.flockId)?.name ?? "Flock"
                let breedName = store.breed(entry.breedId)?.name
                items.append(HItem(
                    date: entry.date, icon: "oval.portrait.fill", color: AppColor.accent,
                    title: "\(entry.eggsCollected) eggs collected",
                    subtitle: "\(flockName)\(breedName != nil ? " • \(breedName!)" : "") • \(shortDate(entry.date))",
                    amount: nil, record: nil))
            }
        }
        if filter == .all || filter == .sold {
            for record in store.records(.sale) {
                items.append(HItem(
                    date: record.date, icon: "arrow.up.circle.fill", color: AppColor.good,
                    title: record.title, subtitle: "Sale • \(shortDate(record.date))",
                    amount: "+" + formatMoney(record.amount), record: record))
            }
        }
        if filter == .all || filter == .spent {
            for record in store.records(.expense) {
                items.append(HItem(
                    date: record.date, icon: "arrow.down.circle.fill", color: AppColor.problem,
                    title: record.title, subtitle: "Expense • \(shortDate(record.date))",
                    amount: "-" + formatMoney(record.amount), record: record))
            }
        }
        if filter == .all {
            for record in store.records(.note) {
                items.append(HItem(
                    date: record.date, icon: "note.text", color: AppColor.accentActive,
                    title: record.title, subtitle: "Note • \(shortDate(record.date))",
                    amount: nil, record: record))
            }
        }
        return items.sorted { $0.date > $1.date }
    }
}
