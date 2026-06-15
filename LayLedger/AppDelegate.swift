import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

final class AppDelegate: UIResponder, UIApplicationDelegate {
    
    private lazy var registry = PluginRegistry(host: self)
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        registry.dispatchInstall()
        
        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            registry.pushPlugin.swallow(remote)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onActivation),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    @objc private func onActivation() {
        registry.appsFlyerPlugin.startTracking()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        messaging.token { token, err in
            guard err == nil, let t = token else { return }
            UserDefaults.standard.set(t, forKey: LedgerDictKey.fcm)
            UserDefaults.standard.set(t, forKey: LedgerDictKey.push)
            UserDefaults(suiteName: LedgerGlossary.suiteTome)?.set(t, forKey: "shared_fcm")
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        registry.pushPlugin.swallow(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        registry.pushPlugin.swallow(response.notification.request.content.userInfo)
        completionHandler()
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        registry.pushPlugin.swallow(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        registry.fusionPlugin.absorbAttribution(data)
    }
    
    func onConversionDataFail(_ error: Error) {
        registry.fusionPlugin.absorbAttribution([
            "error": true,
            "error_desc": error.localizedDescription
        ])
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let link = result.deepLink else { return }
        registry.fusionPlugin.absorbDeeplink(link.clickEvent)
    }
}

protocol DelegatePlugin: AnyObject {
    var pluginID: String { get }
    func onInstall()
}

final class PluginRegistry {
    private weak var host: AppDelegate?
    private var plugins: [DelegatePlugin] = []
    
    let firebasePlugin = FirebasePlugin()
    let messagingPlugin: MessagingPlugin
    let notificationsPlugin: NotificationsPlugin
    let appsFlyerPlugin: AppsFlyerPlugin
    let fusionPlugin = FusionPlugin()
    let pushPlugin = PushPlugin()
    
    init(host: AppDelegate) {
        self.host = host
        self.messagingPlugin = MessagingPlugin(host: host)
        self.notificationsPlugin = NotificationsPlugin(host: host)
        self.appsFlyerPlugin = AppsFlyerPlugin(host: host)
        
        register(firebasePlugin)
        register(messagingPlugin)
        register(notificationsPlugin)
        register(appsFlyerPlugin)
        register(fusionPlugin)
        register(pushPlugin)
    }
    
    func register(_ plugin: DelegatePlugin) {
        plugins.append(plugin)
    }
    
    func dispatchInstall() {
        for plugin in plugins {
            plugin.onInstall()
        }
    }
}

final class FirebasePlugin: DelegatePlugin {
    let pluginID = "firebase"
    
    func onInstall() {
        FirebaseApp.configure()
    }
}

final class MessagingPlugin: DelegatePlugin {
    let pluginID = "messaging"
    private weak var host: MessagingDelegate?
    
    init(host: MessagingDelegate) {
        self.host = host
    }
    
    func onInstall() {
        Messaging.messaging().delegate = host
        UIApplication.shared.registerForRemoteNotifications()
    }
}

final class NotificationsPlugin: DelegatePlugin {
    let pluginID = "notifications"
    private weak var host: UNUserNotificationCenterDelegate?
    
    init(host: UNUserNotificationCenterDelegate) {
        self.host = host
    }
    
    func onInstall() {
        UNUserNotificationCenter.current().delegate = host
    }
}

final class AppsFlyerPlugin: DelegatePlugin {
    let pluginID = "appsFlyer"
    private weak var attDelegate: AppsFlyerLibDelegate?
    private weak var linkDelegate: DeepLinkDelegate?
    
    init(host: AppDelegate) {
        self.attDelegate = host
        self.linkDelegate = host
    }
    
    func onInstall() {
        let sdk = AppsFlyerLib.shared()
        sdk.appsFlyerDevKey = LedgerGlossary.trackerKey
        sdk.appleAppID = LedgerGlossary.appCode
        sdk.delegate = attDelegate
        sdk.deepLinkDelegate = linkDelegate
        sdk.isDebug = false
    }
    
    func startTracking() {
        if #available(iOS 14, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                    UserDefaults.standard.set(status.rawValue, forKey: "att_status")
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }
}

final class FusionPlugin: DelegatePlugin {
    let pluginID = "fusion"
    
    private var scribblesBuffer: [AnyHashable: Any] = [:]
    private var glintsBuffer: [AnyHashable: Any] = [:]
    private var fuseTimer: Timer?
    
    func onInstall() {}
    
    func absorbAttribution(_ data: [AnyHashable: Any]) {
        scribblesBuffer = data
        scheduleFuse()
        if !glintsBuffer.isEmpty { performFuse() }
    }
    
    func absorbDeeplink(_ data: [AnyHashable: Any]) {
        guard !UserDefaults.standard.bool(forKey: LedgerDictKey.primed) else { return }
        glintsBuffer = data
        NotificationCenter.default.post(
            name: .deeplinksInkwell,
            object: nil,
            userInfo: ["deeplinksData": data]
        )
        fuseTimer?.invalidate()
        if !scribblesBuffer.isEmpty { performFuse() }
    }
    
    private func scheduleFuse() {
        fuseTimer?.invalidate()
        fuseTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.performFuse()
        }
    }
    
    private func performFuse() {
        var combined = scribblesBuffer
        for (k, v) in glintsBuffer {
            let prefixed = "deep_\(k)"
            if combined[prefixed] == nil {
                combined[prefixed] = v
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            NotificationCenter.default.post(
                name: .attributionInkwell,
                object: nil,
                userInfo: ["conversionData": combined]
            )
        }
    }
}

final class PushPlugin: DelegatePlugin {
    let pluginID = "push"
    
    func onInstall() {}
    
    func swallow(_ payload: [AnyHashable: Any]) {
        guard let url = extract(payload) else { return }
        UserDefaults.standard.set(url, forKey: LedgerDictKey.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            NotificationCenter.default.post(
                name: .pushQuill,
                object: nil,
                userInfo: ["temp_url": url]
            )
        }
    }
    
    private func extract(_ payload: [AnyHashable: Any]) -> String? {
        if let direct = payload["url"] as? String { return direct }
        if let nested = payload["data"] as? [String: Any],
           let url = nested["url"] as? String { return url }
        if let aps = payload["aps"] as? [String: Any],
           let nested = aps["data"] as? [String: Any],
           let url = nested["url"] as? String { return url }
        if let custom = payload["custom"] as? [String: Any],
           let url = custom["target_url"] as? String { return url }
        return nil
    }
}
