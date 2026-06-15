import Foundation

enum LedgerMishap: Error, CustomStringConvertible {
    case nibBroken(at: String)
    case scrollFrayed(at: String)
    case runnerLost(stage: String)
    case clerksOverloaded(coolDown: TimeInterval)
    case quillExpired(stage: String)
    case archiveBarred(httpCode: Int)
    case vellumSealed(reason: String)
    
    var description: String {
        switch self {
        case .nibBroken(let at): return "nibBroken(\(at))"
        case .scrollFrayed(let at): return "scrollFrayed(\(at))"
        case .runnerLost(let stage): return "runnerLost(\(stage))"
        case .clerksOverloaded(let cd): return "clerksOverloaded(cd=\(cd))"
        case .quillExpired(let stage): return "quillExpired(\(stage))"
        case .archiveBarred(let code): return "archiveBarred(\(code))"
        case .vellumSealed(let reason): return "vellumSealed(\(reason))"
        }
    }
    
    var isSealed: Bool {
        switch self {
        case .archiveBarred, .vellumSealed: return true
        default: return false
        }
    }
    
    var isRunner: Bool {
        switch self {
        case .runnerLost, .clerksOverloaded, .quillExpired: return true
        default: return false
        }
    }
}
