import Foundation
import AppsFlyerLib

protocol Tracer {
    func trace(deviceID: String) async throws -> [String: Any]
}

final class AppsFlyerTracer: Tracer {
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    func trace(deviceID: String) async throws -> [String: Any] {
        var components = URLComponents(string: "https://gcdsdk.appsflyer.com/install_data/v4.0/id\(LedgerGlossary.appCode)")
        components?.queryItems = [
            URLQueryItem(name: "devkey", value: LedgerGlossary.trackerKey),
            URLQueryItem(name: "device_id", value: deviceID)
        ]
        
        guard let url = components?.url else {
            throw LedgerMishap.scrollFrayed(at: "tracer.url")
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw LedgerMishap.runnerLost(stage: "tracer.http")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LedgerMishap.scrollFrayed(at: "tracer.json")
        }
        
        return json
    }
}
