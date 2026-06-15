import Foundation
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging
import WebKit

protocol Quartermaster {
    func ration(manifest: [String: Any]) async throws -> String
}

final class HTTPQuartermaster: Quartermaster {
    
    private let session: URLSession
    private let recess: [Double] = [84.0, 168.0, 336.0]
    
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    private var browserAgent: String = WKWebView().value(forKey: "userAgent") as? String ?? ""
    
    func ration(manifest: [String: Any]) async throws -> String {
        guard let endpoint = URL(string: LedgerGlossary.backendVellum) else {
            throw LedgerMishap.scrollFrayed(at: "quartermaster.url")
        }
        
        var body: [String: Any] = manifest
        body["os"] = "iOS"
        body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        body["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        body["store_id"] = "id\(LedgerGlossary.appCode)"
        body["push_token"] = UserDefaults.standard.string(forKey: LedgerDictKey.push)
            ?? Messaging.messaging().fcmToken
        body["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(browserAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        var lastMishap: Error?
        
        for (idx, gap) in recess.enumerated() {
            do {
                return try await singleSally(request)
            } catch let mishap as LedgerMishap {
                if mishap.isSealed {
                    throw mishap
                }
                if case .clerksOverloaded(let coolDown) = mishap {
                    try await Task.sleep(nanoseconds: UInt64(coolDown * 1_000_000_000))
                    continue
                }
                lastMishap = mishap
                if idx < recess.count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
                }
            } catch {
                lastMishap = error
                if idx < recess.count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
                }
            }
        }
        
        if let lastMishap = lastMishap {
            throw lastMishap
        }
        throw LedgerMishap.runnerLost(stage: "quartermaster.exhausted")
    }
    
    private func singleSally(_ request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw LedgerMishap.runnerLost(stage: "quartermaster.response")
        }
        
        if http.statusCode == 404 {
            throw LedgerMishap.archiveBarred(httpCode: 404)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LedgerMishap.scrollFrayed(at: "quartermaster.json")
        }
        
        guard let ok = json["ok"] as? Bool else {
            throw LedgerMishap.scrollFrayed(at: "quartermaster.missingOk")
        }
        
        if !ok {
            throw LedgerMishap.vellumSealed(reason: "okFalse")
        }
        
        guard let url = json["url"] as? String, !url.isEmpty else {
            throw LedgerMishap.scrollFrayed(at: "quartermaster.missingURL")
        }
        
        return url
    }
}
