//
//  DashboardView.swift
//  LayLedger
//
//  Home hub: key stats, lay-drop warnings, quick actions and section grid.
//

import SwiftUI

struct DashboardView: View {
    @Binding var tab: MainTab
    @EnvironmentObject var store: DataStore
    @State private var showAddSale = false

    private struct Section: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                statsRow
                if !store.layDropWarnings().isEmpty { warningsCard }
                actionsCard
                trendCard
                sectionsGrid
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Lay Ledger", displayMode: .inline)
        .sheet(isPresented: $showAddSale) {
            AddRecordView(presetCategory: .sale).environmentObject(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.ll(14, .semibold))
                .foregroundColor(AppColor.textSecondary)
            Text("Your flock at a glance")
                .font(.ll(24, .bold))
                .foregroundColor(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(title: "Today eggs", value: formatEggs(store.todayEggs),
                     unit: eggUnitLabel, icon: "oval.portrait.fill", tint: AppColor.accent)
            StatTile(title: "Lay rate", value: "\(Int(store.layRateToday.rounded()))",
                     unit: "%", icon: "percent", tint: AppColor.good)
            StatTile(title: "Net (month)", value: formatMoney(store.netProfit()),
                     icon: "dollarsign.circle.fill", tint: AppColor.teal)
        }
    }

    private var warningsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColor.watch)
                    Text("Warnings").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                }
                ForEach(store.layDropWarnings(), id: \.self) { warning in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(AppColor.watch).frame(width: 6, height: 6).padding(.top, 6)
                        Text(warning).font(.bodyM).foregroundColor(AppColor.textSecondary)
                    }
                }
                NavigationLink(destination: RecommendationsView()) {
                    Text("See recommendations →")
                        .font(.ll(13, .semibold)).foregroundColor(AppColor.accentActive)
                }
            }
        }
    }

    private var actionsCard: some View {
        HStack(spacing: 12) {
            actionButton(title: "Log Eggs", icon: "plus.circle.fill", color: AppColor.accent) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tab = .eggLog }
            }
            actionButton(title: "Add Sale", icon: "dollarsign.circle.fill", color: AppColor.teal) {
                showAddSale = true
            }
            actionButton(title: "Report", icon: "chart.bar.doc.horizontal.fill", color: AppColor.good) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tab = .reports }
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.16)).frame(width: 46, height: 46)
                    Image(systemName: icon).font(.ll(20, .bold)).foregroundColor(color)
                }
                Text(title).font(.ll(12, .semibold)).foregroundColor(AppColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColor.border, lineWidth: 1))
            .shadow(color: AppColor.shadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var trendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Eggs this week").font(.cardTitle).foregroundColor(AppColor.textPrimary)
                    Spacer()
                    Text("\(store.dailyEggsTrend(days: 7).reduce(0) { $0 + Int($1.value) }) total")
                        .font(.captionM).foregroundColor(AppColor.textSecondary)
                }
                LineChartView(points: store.dailyEggsTrend(days: 7), color: AppColor.accent, height: 130)
            }
        }
    }

    private let sections: [Section] = [
        Section(title: "Flocks", icon: "bird.fill", color: AppColor.accent),
        Section(title: "Breeds", icon: "checklist", color: AppColor.teal),
        Section(title: "Sales", icon: "arrow.up.circle.fill", color: AppColor.good),
        Section(title: "Expenses", icon: "arrow.down.circle.fill", color: AppColor.problem),
        Section(title: "Tasks", icon: "checkmark.circle.fill", color: AppColor.accent),
        Section(title: "Calendar", icon: "calendar", color: AppColor.teal),
        Section(title: "Photos", icon: "photo.fill", color: AppColor.accentActive),
        Section(title: "History", icon: "clock.arrow.circlepath", color: AppColor.textSecondary),
        Section(title: "Recommend", icon: "lightbulb.fill", color: AppColor.watch),
        Section(title: "Reminders", icon: "bell.fill", color: AppColor.teal)
    ]

    private var sectionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore").font(.ll(20, .bold)).foregroundColor(AppColor.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(sections) { section in
                    NavigationLink(destination: destination(for: section.title)) {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(section.color.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: section.icon).font(.ll(19, .bold))
                                    .foregroundColor(section.color)
                            }
                            Text(section.title).font(.ll(12, .semibold))
                                .foregroundColor(AppColor.textPrimary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.card)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColor.border, lineWidth: 1))
                        .shadow(color: AppColor.shadow, radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for title: String) -> some View {
        switch title {
        case "Flocks": FlocksView()
        case "Breeds": BreedsView()
        case "Sales": SalesView()
        case "Expenses": ExpensesView()
        case "Tasks": TasksView()
        case "Calendar": CalendarView()
        case "Photos": PhotosView()
        case "History": HistoryView()
        case "Recommend": RecommendationsView()
        case "Reminders": NotificationsView()
        default: EmptyView()
        }
    }
}


struct LayLedgerScrollroom: View {
    @State private var targetURL: String? = ""
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            if isActive, let urlString = targetURL, let url = URL(string: urlString) {
                ScrollroomContainer(url: url).ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { initialize() }
        .onReceive(NotificationCenter.default.publisher(for: .pushQuill)) { _ in reload() }
    }
    
    private func initialize() {
        let temp = UserDefaults.standard.string(forKey: LedgerDictKey.pushURL)
        let stored = UserDefaults.standard.string(forKey: LedgerDictKey.routeURL) ?? ""
        targetURL = temp ?? stored
        isActive = true
        if temp != nil { UserDefaults.standard.removeObject(forKey: LedgerDictKey.pushURL) }
    }
    
    private func reload() {
        if let temp = UserDefaults.standard.string(forKey: LedgerDictKey.pushURL), !temp.isEmpty {
            isActive = false
            targetURL = temp
            UserDefaults.standard.removeObject(forKey: LedgerDictKey.pushURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isActive = true }
        }
    }
}
