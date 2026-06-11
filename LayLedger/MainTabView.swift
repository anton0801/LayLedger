//
//  MainTabView.swift
//  LayLedger
//
//  Dashboard-driven shell with a custom floating tab bar.
//

import SwiftUI

enum MainTab: Int, CaseIterable, Identifiable {
    case dashboard, eggLog, reports, settings
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .eggLog: return "Egg Log"
        case .reports: return "Reports"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .eggLog: return "oval.portrait.fill"
        case .reports: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @State private var tab: MainTab = .dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.bgGradient.ignoresSafeArea()

            Group {
                switch tab {
                case .dashboard:
                    NavigationView { DashboardView(tab: $tab) }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .eggLog:
                    NavigationView { EggLogView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .reports:
                    NavigationView { ReportsView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .settings:
                    NavigationView { SettingsView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                }
            }

            CustomTabBar(selection: $tab)
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Circle().fill(AppColor.accent.opacity(0.18)).frame(width: 38, height: 38)
                            }
                            Image(systemName: tab.icon)
                                .font(.ll(17, .semibold))
                                .foregroundColor(isSelected ? AppColor.accentActive : AppColor.textDisabled)
                                .scaleEffect(isSelected ? 1.05 : 1)
                        }
                        .frame(height: 38)
                        Text(tab.title)
                            .font(.ll(10, .semibold))
                            .foregroundColor(isSelected ? AppColor.accentActive : AppColor.textDisabled)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppColor.border, lineWidth: 1))
        .shadow(color: AppColor.shadow, radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
