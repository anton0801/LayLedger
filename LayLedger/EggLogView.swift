//
//  EggLogView.swift
//  LayLedger
//
//  The core daily egg log: today's totals, per-breed split, entry form and trends.
//

import SwiftUI

struct EggLogView: View {
    @EnvironmentObject var store: DataStore

    @State private var selectedFlockId: UUID? = nil
    @State private var selectedBreedId: UUID? = nil
    @State private var collected = 0
    @State private var cracked = 0
    @State private var sold = 0
    @State private var date = Date()
    @State private var trendMode = 0
    @State private var showToast = false

    private var selectedFlock: Flock? { store.flock(selectedFlockId) ?? store.activeFlocks.first }
    private var kept: Int { max(0, collected - cracked - sold) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if store.activeFlocks.isEmpty {
                    noFlocks
                } else {
                    summaryCard
                    splitCard
                    entryForm
                    trendsCard
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Egg Log", displayMode: .inline)
        .onAppear { if selectedFlockId == nil { selectedFlockId = store.activeFlocks.first?.id } }
        .toast(isShowing: $showToast, message: "Entry saved")
    }

    private var noFlocks: some View {
        EmptyStateView(icon: "bird.fill", title: "Add a flock first",
                       message: "You need at least one flock before logging eggs.") { }
            .overlay(
                NavigationLink(destination: FlocksView()) {
                    Text("Go to Flocks →").font(.ll(14, .semibold)).foregroundColor(AppColor.accentActive)
                }
                .padding(.bottom, 20), alignment: .bottom)
    }

    // MARK: Summary

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today").font(.captionM).foregroundColor(AppColor.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(formatEggs(store.todayEggs)).font(.ll(40, .bold))
                                .foregroundColor(AppColor.textPrimary)
                            Text(eggUnitLabel).font(.bodyM).foregroundColor(AppColor.textSecondary)
                        }
                        Text("\(store.totalActiveBirds) birds in \(store.activeFlocks.count) flock(s)")
                            .font(.captionM).foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                    RingProgress(percent: store.layRateToday, color: AppColor.accent, size: 96)
                }
                Text("Lay rate vs flock size")
                    .font(.ll(11, .medium)).foregroundColor(AppColor.textDisabled)
            }
        }
    }

    private var splitCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Eggs by breed (7 days)").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                let data = store.eggsByBreedData(days: 7)
                if data.isEmpty {
                    Text("No breed data yet — log eggs by breed to see the split.")
                        .font(.captionM).foregroundColor(AppColor.textSecondary)
                } else {
                    BarChartView(bars: data, height: 130)
                }
                Divider().background(AppColor.border)
                Text("Sold / kept (30 days)").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                let split = store.soldKeptSplit(days: 30)
                SplitBar(sold: split.sold, kept: split.kept)
            }
        }
    }

    // MARK: Entry form

    private var entryForm: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Log collection").font(.cardTitle).foregroundColor(AppColor.textPrimary)

                pickerRow(title: "Flock", value: selectedFlock?.name ?? "—") {
                    ForEach(store.activeFlocks) { f in
                        Button(f.name) { selectedFlockId = f.id; selectedBreedId = nil }
                    }
                }
                pickerRow(title: "Breed", value: breedName) {
                    Button("Whole flock") { selectedBreedId = nil }
                    ForEach(currentBreeds) { b in
                        Button(b.name) { selectedBreedId = b.id }
                    }
                }

                StepperField(label: "Eggs collected", value: $collected)
                StepperField(label: "Cracked / discarded", value: $cracked)
                StepperField(label: "Sold", value: $sold)

                HStack {
                    Text("Kept").font(.bodyM).foregroundColor(AppColor.textSecondary)
                    Spacer()
                    Text("\(kept)").font(.ll(17, .bold)).foregroundColor(AppColor.teal)
                }

                Card(padding: 0) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .accentColor(AppColor.accentActive)
                        .foregroundColor(AppColor.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                }

                HStack(spacing: 10) {
                    LLButton(title: "Quick +1", icon: "plus", kind: .secondary, fullWidth: true) {
                        store.quickAddEgg(flockId: selectedFlock?.id ?? UUID(), breedId: selectedBreedId)
                        bump()
                    }
                    LLButton(title: "Save Entry", icon: "checkmark") { saveEntry(reset: true) }
                }
                LLButton(title: "Add Another", icon: "plus.square.on.square", kind: .ghost) {
                    saveEntry(reset: false)
                }
            }
        }
    }

    private var currentBreeds: [Breed] {
        guard let f = selectedFlock else { return [] }
        return store.breeds(for: f)
    }
    private var breedName: String {
        store.breed(selectedBreedId)?.name ?? "Whole flock"
    }

    private func pickerRow<Content: View>(title: String, value: String,
                                          @ViewBuilder menu: () -> Content) -> some View {
        HStack {
            Text(title).font(.bodyM).foregroundColor(AppColor.textSecondary)
            Spacer()
            Menu {
                menu()
            } label: {
                HStack(spacing: 6) {
                    Text(value).font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary)
                    Image(systemName: "chevron.up.chevron.down").font(.ll(11, .semibold))
                        .foregroundColor(AppColor.textDisabled)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(AppColor.bgSecondary).cornerRadius(10)
            }
        }
    }

    // MARK: Trends

    private var trendsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Trends (14 days)").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                    Spacer()
                }
                LLSegmented(options: [0, 1], selection: $trendMode) { $0 == 0 ? "Daily eggs" : "Lay rate" }
                if trendMode == 0 {
                    LineChartView(points: store.dailyEggsTrend(days: 14), color: AppColor.accent, height: 150)
                } else {
                    LineChartView(points: store.layRateTrend(days: 14), color: AppColor.teal, height: 150)
                }
            }
        }
    }

    // MARK: Actions

    private func saveEntry(reset: Bool) {
        guard let flock = selectedFlock, collected > 0 else { return }
        var entry = EggEntry(flockId: flock.id)
        entry.breedId = selectedBreedId
        entry.date = date
        entry.eggsCollected = collected
        entry.crackedDiscarded = cracked
        entry.sold = sold
        entry.kept = kept
        store.addEggEntry(entry)
        bump()
        if reset {
            collected = 0; cracked = 0; sold = 0
        } else {
            collected = 0; cracked = 0; sold = 0
        }
    }

    private func bump() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showToast = true }
    }
}
