import Foundation

struct LedgerArchive: Codable {
    let scribbles: [String: String]
    let glints: [String: String]
    let routeURL: String?
    let routeMode: String?
    let uninked: Bool
    let consentSigned: Bool
    let consentVoided: Bool
    let consentInkedAt: Date?
}

struct Ledger {
    var scribbles: [String: String] = [:]
    var glints: [String: String] = [:]
    var routeURL: String? = nil
    var routeMode: String? = nil
    var uninked: Bool = true
    var bound: Bool = false
    var organicPenned: Bool = false
    var consentSigned: Bool = false
    var consentVoided: Bool = false
    var consentInkedAt: Date? = nil
    
    var scribblesReady: Bool { !scribbles.isEmpty }
    var organicLedger: Bool { scribbles["af_status"] == "Organic" }
    
    var consentRipe: Bool {
        guard !consentSigned && !consentVoided else { return false }
        if let date = consentInkedAt {
            let elapsed = Date().timeIntervalSince(date) / 86400
            return elapsed >= 3
        }
        return true
    }
    
    static func revive(from archive: LedgerArchive) -> Ledger {
        var l = Ledger()
        l.scribbles = archive.scribbles
        l.glints = archive.glints
        l.routeURL = archive.routeURL
        l.routeMode = archive.routeMode
        l.uninked = archive.uninked
        l.consentSigned = archive.consentSigned
        l.consentVoided = archive.consentVoided
        l.consentInkedAt = archive.consentInkedAt
        return l
    }
    
    func crystallize() -> LedgerArchive {
        LedgerArchive(
            scribbles: scribbles, glints: glints,
            routeURL: routeURL, routeMode: routeMode,
            uninked: uninked,
            consentSigned: consentSigned, consentVoided: consentVoided,
            consentInkedAt: consentInkedAt
        )
    }
}

enum ScrollOutcome: Equatable {
    case dormant
    case askConsent
    case unfurlScroll
    case stricken
}

final class ProgramSeal {
    private var sealed: Bool = false
    private let lock = NSLock()
    
    func trySeal() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !sealed else { return false }
        sealed = true
        return true
    }
    
    var isSealed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return sealed
    }
}
