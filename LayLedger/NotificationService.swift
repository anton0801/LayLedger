//
//  NotificationService.swift
//  LayLedger
//
//  Real local-notification scheduling via UNUserNotificationCenter.
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    // Identifiers
    static let dailyEggLogID = "ll.dailyEggLog"
    static let weeklySummaryID = "ll.weeklySummary"
    static let layDropID = "ll.layDrop"

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func scheduleDailyEggLog(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Egg log reminder"
        content.body = "Time to log today's eggs in Lay Ledger."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.dailyEggLogID, content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleWeeklySummary(weekday: Int, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Weekly summary"
        content.body = "Review this week's eggs, sales and profit."
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday // 1 = Sunday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.weeklySummaryID, content: content, trigger: trigger)
        center.add(request)
    }

    /// Fires a near-immediate alert when a lay drop has been detected.
    func fireLayDropAlert(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Lay rate drop"
        content.body = message
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4, repeats: false)
        let request = UNNotificationRequest(identifier: Self.layDropID, content: content, trigger: trigger)
        center.add(request)
    }

    func cancel(_ identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
