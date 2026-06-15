import Foundation

protocol Tome {
    func archive(_ archive: LedgerArchive)
    func inkRoute(url: String, mode: String)
    func raisePrimedFlag()
    func excavate() -> LedgerArchive
}

final class JSONTome: Tome {
    
    private let fm = FileManager.default
    private let dataDir: URL
    private let homeStore: UserDefaults
    private let suiteStore: UserDefaults
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.dataDir = docs.appendingPathComponent("LedgerTome", isDirectory: true)
        if !fm.fileExists(atPath: dataDir.path) {
            try? fm.createDirectory(at: dataDir, withIntermediateDirectories: true)
        }
        self.homeStore = UserDefaults.standard
        self.suiteStore = UserDefaults(suiteName: LedgerGlossary.suiteTome) ?? .standard
    }
    
    private var archiveURL: URL {
        dataDir.appendingPathComponent(LedgerGlossary.tomeFile)
    }
    
    func archive(_ archive: LedgerArchive) {
        let veiled = VeiledTome(
            scribbles: cloakDict(archive.scribbles),
            glints: cloakDict(archive.glints),
            routeURL: archive.routeURL,
            routeMode: archive.routeMode,
            uninked: archive.uninked,
            consentSigned: archive.consentSigned,
            consentVoided: archive.consentVoided,
            consentInkedAt: archive.consentInkedAt
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        
        do {
            let data = try encoder.encode(veiled)
            try data.write(to: archiveURL, options: .atomic)
        } catch {
            print("\(LedgerGlossary.logScroll) Tome archive failed: \(error)")
        }
        
        suiteStore.set(archive.consentSigned, forKey: "ll_consent_signed")
        suiteStore.set(archive.consentVoided, forKey: "ll_consent_voided")
        if let date = archive.consentInkedAt {
            suiteStore.set(date.timeIntervalSince1970, forKey: "ll_consent_inked_at")
        }
        homeStore.set(archive.consentSigned, forKey: "ll_consent_signed")
        homeStore.set(archive.consentVoided, forKey: "ll_consent_voided")
        if let date = archive.consentInkedAt {
            homeStore.set(date.timeIntervalSince1970, forKey: "ll_consent_inked_at")
        }
    }
    
    func inkRoute(url: String, mode: String) {
        suiteStore.set(url, forKey: LedgerDictKey.routeURL)
        homeStore.set(url, forKey: LedgerDictKey.routeURL)
        suiteStore.set(mode, forKey: LedgerDictKey.routeMode)
    }
    
    func raisePrimedFlag() {
        suiteStore.set(true, forKey: LedgerDictKey.primed)
        homeStore.set(true, forKey: LedgerDictKey.primed)
    }
    
    func excavate() -> LedgerArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        
        if fm.fileExists(atPath: archiveURL.path),
           let data = try? Data(contentsOf: archiveURL),
           let veiled = try? decoder.decode(VeiledTome.self, from: data) {
            return LedgerArchive(
                scribbles: uncloakDict(veiled.scribbles),
                glints: uncloakDict(veiled.glints),
                routeURL: veiled.routeURL,
                routeMode: veiled.routeMode,
                uninked: veiled.uninked,
                consentSigned: veiled.consentSigned,
                consentVoided: veiled.consentVoided,
                consentInkedAt: veiled.consentInkedAt
            )
        }
        
        return restoreFromDefaults()
    }
    
    private func restoreFromDefaults() -> LedgerArchive {
        let routeURL = homeStore.string(forKey: LedgerDictKey.routeURL)
            ?? suiteStore.string(forKey: LedgerDictKey.routeURL)
        let routeMode = suiteStore.string(forKey: LedgerDictKey.routeMode)
        let primed = suiteStore.bool(forKey: LedgerDictKey.primed)
        
        let signed = suiteStore.bool(forKey: "ll_consent_signed")
            || homeStore.bool(forKey: "ll_consent_signed")
        let voided = suiteStore.bool(forKey: "ll_consent_voided")
            || homeStore.bool(forKey: "ll_consent_voided")
        let inkedTs = suiteStore.double(forKey: "ll_consent_inked_at")
        let inkedAt: Date? = inkedTs > 0 ? Date(timeIntervalSince1970: inkedTs) : nil
        
        return LedgerArchive(
            scribbles: [:], glints: [:],
            routeURL: routeURL, routeMode: routeMode,
            uninked: !primed,
            consentSigned: signed, consentVoided: voided, consentInkedAt: inkedAt
        )
    }
    
    private func cloakDict(_ dict: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in dict { result[k] = cloak(v) }
        return result
    }
    
    private func uncloakDict(_ dict: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in dict { result[k] = uncloak(v) ?? v }
        return result
    }
    
    private func cloak(_ input: String) -> String {
        let b64 = Data(input.utf8).base64EncodedString()
        return b64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: ".")
    }
    
    private func uncloak(_ input: String) -> String? {
        let b64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: ".", with: "/")
        guard let data = Data(base64Encoded: b64),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}

struct VeiledTome: Codable {
    let scribbles: [String: String]
    let glints: [String: String]
    let routeURL: String?
    let routeMode: String?
    let uninked: Bool
    let consentSigned: Bool
    let consentVoided: Bool
    let consentInkedAt: Date?
}
