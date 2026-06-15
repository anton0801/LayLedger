import Foundation
import UIKit
import UserNotifications

protocol Sentry {
    func challenge() async -> Bool
    func wireSummoner()
}

final class NotificationSentry: Sentry {
    
    func challenge() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let onceMark = SoleMark()
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                if let error = error {
                    print("\(LedgerGlossary.logScroll) Sentry error: \(error)")
                }
                DispatchQueue.main.async {
                    guard onceMark.tryMark() else { return }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func wireSummoner() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

final class SoleMark {
    private var marked = false
    private let lock = NSLock()
    
    func tryMark() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !marked else { return false }
        marked = true
        return true
    }
}
