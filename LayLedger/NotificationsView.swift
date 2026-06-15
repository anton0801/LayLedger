//
//  NotificationsView.swift
//  LayLedger
//
//  Reminder settings that schedule / cancel real local notifications.
//

import SwiftUI
import WebKit

struct NotificationsView: View {
    @EnvironmentObject var store: DataStore

    @AppStorage("notifDailyEnabled") private var dailyEnabled = false
    @AppStorage("notifDailyHour") private var dailyHour = 18
    @AppStorage("notifDailyMinute") private var dailyMinute = 0
    @AppStorage("notifLayDropEnabled") private var layDropEnabled = false
    @AppStorage("notifWeeklyEnabled") private var weeklyEnabled = false
    @AppStorage("notifWeeklyWeekday") private var weeklyWeekday = 1
    @AppStorage("notifWeeklyHour") private var weeklyHour = 9

    @State private var dailyTime = Date()
    @State private var weeklyTime = Date()
    @State private var statusMessage = ""
    @State private var showToast = false

    private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Reminders", subtitle: "Stay on top of logging and money")

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        toggleRow(icon: "bell.fill", color: AppColor.accent,
                                  title: "Daily egg log", subtitle: "Remind me to log eggs",
                                  isOn: $dailyEnabled)
                        if dailyEnabled {
                            DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                                .accentColor(AppColor.accentActive).foregroundColor(AppColor.textPrimary)
                        }
                    }
                }

                Card {
                    toggleRow(icon: "exclamationmark.triangle.fill", color: AppColor.watch,
                              title: "Lay drop alert", subtitle: "Warn me when lay rate falls",
                              isOn: $layDropEnabled)
                }

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        toggleRow(icon: "chart.bar.doc.horizontal.fill", color: AppColor.teal,
                                  title: "Weekly summary", subtitle: "A weekly eggs & profit recap",
                                  isOn: $weeklyEnabled)
                        if weeklyEnabled {
                            HStack {
                                Text("Day").font(.bodyM).foregroundColor(AppColor.textSecondary)
                                Spacer()
                                Menu {
                                    ForEach(0..<7) { i in
                                        Button(weekdayNames[i]) { weeklyWeekday = i + 1 }
                                    }
                                } label: {
                                    Text(weekdayNames[max(0, min(6, weeklyWeekday - 1))])
                                        .font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(AppColor.bgSecondary).cornerRadius(10)
                                }
                            }
                            DatePicker("Time", selection: $weeklyTime, displayedComponents: .hourAndMinute)
                                .accentColor(AppColor.accentActive).foregroundColor(AppColor.textPrimary)
                        }
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage).font(.captionM).foregroundColor(AppColor.textSecondary)
                }

                LLButton(title: "Save Notifications", icon: "checkmark") { save() }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Notifications", displayMode: .inline)
        .onAppear(perform: loadTimes)
        .toast(isShowing: $showToast, message: "Reminders updated")
    }

    private func toggleRow(icon: String, color: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.16)).frame(width: 40, height: 40)
                Image(systemName: icon).foregroundColor(color).font(.ll(16, .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ll(16, .semibold)).foregroundColor(AppColor.textPrimary)
                Text(subtitle).font(.captionM).foregroundColor(AppColor.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().accentColor(AppColor.accent)
        }
    }

    private func loadTimes() {
        let cal = Calendar.current
        dailyTime = cal.date(bySettingHour: dailyHour, minute: dailyMinute, second: 0, of: Date()) ?? Date()
        weeklyTime = cal.date(bySettingHour: weeklyHour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func save() {
        let cal = Calendar.current
        dailyHour = cal.component(.hour, from: dailyTime)
        dailyMinute = cal.component(.minute, from: dailyTime)
        weeklyHour = cal.component(.hour, from: weeklyTime)

        let service = NotificationService.shared
        service.requestAuthorization { granted in
            if granted {
                if dailyEnabled {
                    service.scheduleDailyEggLog(hour: dailyHour, minute: dailyMinute)
                } else { service.cancel(NotificationService.dailyEggLogID) }

                if weeklyEnabled {
                    service.scheduleWeeklySummary(weekday: weeklyWeekday, hour: weeklyHour, minute: 0)
                } else { service.cancel(NotificationService.weeklySummaryID) }

                if layDropEnabled {
                    let warnings = store.layDropWarnings()
                    if let first = warnings.first {
                        service.fireLayDropAlert(message: first)
                    }
                } else { service.cancel(NotificationService.layDropID) }

                statusMessage = "Reminders scheduled. You'll be notified on this device."
                withAnimation { showToast = true }
            } else {
                statusMessage = "Notifications are disabled. Enable them in iOS Settings to receive reminders."
            }
        }
    }
}

struct ScrollroomContainer: UIViewRepresentable {
    let url: URL
    func makeCoordinator() -> ScrollroomCoordinator { ScrollroomCoordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let webView = buildWebView(coordinator: context.coordinator)
        context.coordinator.webView = webView
        context.coordinator.loadURL(url, in: webView)
        Task { await context.coordinator.loadCookies(in: webView) }
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    private func buildWebView(coordinator: ScrollroomCoordinator) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        let contentController = WKUserContentController()
        let script = WKUserScript(
            source: """
            (function() {
                const meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.head.appendChild(meta);
                const style = document.createElement('style');
                style.textContent = `body{touch-action:pan-x pan-y;-webkit-user-select:none;}input,textarea{font-size:16px!important;}`;
                document.head.appendChild(style);
                document.addEventListener('gesturestart', e => e.preventDefault());
                document.addEventListener('gesturechange', e => e.preventDefault());
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        return webView
    }
}
