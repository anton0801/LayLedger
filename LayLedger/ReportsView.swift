//
//  ReportsView.swift
//  LayLedger
//
//  Analytics with custom charts plus real PDF export and share.
//

import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var store: DataStore
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                summaryGrid

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Eggs by breed (7 days)").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                        let data = store.eggsByBreedData(days: 7)
                        if data.isEmpty {
                            placeholder("Log eggs by breed to compare breeds.")
                        } else {
                            BarChartView(bars: data, height: 170)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lay rate trend (14 days)").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                        LineChartView(points: store.layRateTrend(days: 14), color: AppColor.teal, height: 160, valueSuffix: "%")
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profit by month").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                        BarChartView(bars: store.profitByMonthData(months: 6), height: 170)
                    }
                }

                LLButton(title: "Export PDF", icon: "doc.richtext") { exportPDF() }
                LLButton(title: "Share summary", icon: "square.and.arrow.up", kind: .secondary) { shareSummary() }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Reports", displayMode: .inline)
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
    }

    private var summaryGrid: some View {
        let eggs30 = (0..<30).reduce(0) { acc, d in
            acc + store.eggs(on: Calendar.current.date(byAdding: .day, value: -d, to: Date()) ?? Date())
        }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Eggs (30d)", value: formatEggs(eggs30), unit: eggUnitLabel,
                     icon: "oval.portrait.fill", tint: AppColor.accent)
            StatTile(title: "Lay rate today", value: "\(Int(store.layRateToday.rounded()))", unit: "%",
                     icon: "percent", tint: AppColor.good)
            StatTile(title: "Income", value: formatMoney(store.totalSales()),
                     icon: "arrow.up.circle.fill", tint: AppColor.teal)
            StatTile(title: "Expenses", value: formatMoney(store.totalExpenses()),
                     icon: "arrow.down.circle.fill", tint: AppColor.problem)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text).font(.captionM).foregroundColor(AppColor.textSecondary).padding(.vertical, 8)
    }

    private var summaryItems: [ReportSummaryItem] {
        let eggs30 = (0..<30).reduce(0) { acc, d in
            acc + store.eggs(on: Calendar.current.date(byAdding: .day, value: -d, to: Date()) ?? Date())
        }
        return [
            ReportSummaryItem(label: "Eggs (last 30 days)", value: "\(eggs30)"),
            ReportSummaryItem(label: "Lay rate today", value: "\(Int(store.layRateToday.rounded()))%"),
            ReportSummaryItem(label: "Total income", value: formatMoney(store.totalSales())),
            ReportSummaryItem(label: "Total expenses", value: formatMoney(store.totalExpenses())),
            ReportSummaryItem(label: "Net profit (month)", value: formatMoney(store.netProfit())),
            ReportSummaryItem(label: "Active birds", value: "\(store.totalActiveBirds)")
        ]
    }

    private func exportPDF() {
        if let url = PDFExportService.generateReport(
            title: "Lay Ledger Report",
            subtitle: mediumDate(Date()),
            summary: summaryItems,
            eggsByBreed: store.eggsByBreedData(days: 7),
            profitByMonth: store.profitByMonthData(months: 6)) {
            shareItems = [url]
            showShare = true
        }
    }

    private func shareSummary() {
        let lines = summaryItems.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
        shareItems = ["Lay Ledger — \(mediumDate(Date()))\n\n\(lines)"]
        showShare = true
    }
}
