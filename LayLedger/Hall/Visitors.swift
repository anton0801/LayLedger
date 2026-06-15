import Foundation
import AppsFlyerLib

final class ExecutionVisitor: InstructionVisitor {
    
    func visit(_ instruction: PushSnatchOp, context: TomeContext) async -> InstructionResult {
        guard let pushURL = UserDefaults.standard.string(forKey: LedgerDictKey.pushURL),
              !pushURL.isEmpty else {
            return .advance
        }
        
        let needsConsent = context.ledger.consentRipe
        
        context.ledger.routeURL = pushURL
        context.ledger.routeMode = "Active"
        context.ledger.uninked = false
        context.ledger.bound = true
        
        context.stable.tome.archive(context.ledger.crystallize())
        context.stable.tome.inkRoute(url: pushURL, mode: "Active")
        context.stable.tome.raisePrimedFlag()
        UserDefaults.standard.removeObject(forKey: LedgerDictKey.pushURL)
        
        return .finalize(needsConsent ? .askConsent : .unfurlScroll)
    }
    
    func visit(_ instruction: ScribblesGateOp, context: TomeContext) async -> InstructionResult {
        guard context.ledger.scribblesReady else {
            return .finalize(.dormant)
        }
        return .advance
    }
    
    func visit(_ instruction: OrganicQuillOp, context: TomeContext) async -> InstructionResult {
        let needsQuill = context.ledger.organicLedger
            && context.ledger.uninked
            && !context.ledger.organicPenned
        
        guard needsQuill else {
            return .advance
        }
        
        context.ledger.organicPenned = true
        context.stable.tome.archive(context.ledger.crystallize())
        
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        guard !context.ledger.bound else {
            return .advance
        }
        
        let deviceID = AppsFlyerLib.shared().getAppsFlyerUID()
        
        do {
            var fetched = try await context.stable.tracer.trace(deviceID: deviceID)
            for (k, v) in context.ledger.glints {
                if fetched[k] == nil { fetched[k] = v }
            }
            let mapped = fetched.mapValues { "\($0)" }
            context.ledger.scribbles = mapped
            context.stable.tome.archive(context.ledger.crystallize())
        } catch {
        }
        
        return .advance
    }
    
    func visit(_ instruction: VellumDispatchOp, context: TomeContext) async -> InstructionResult {
        guard context.ledger.scribblesReady else {
            return .finalize(.dormant)
        }
        
        let manifest = context.ledger.scribbles.mapValues { $0 as Any }
        
        do {
            let url = try await context.stable.quartermaster.ration(manifest: manifest)
            
            let needsConsent = context.ledger.consentRipe
            
            context.ledger.routeURL = url
            context.ledger.routeMode = "Active"
            context.ledger.uninked = false
            context.ledger.bound = true
            
            context.stable.tome.archive(context.ledger.crystallize())
            context.stable.tome.inkRoute(url: url, mode: "Active")
            context.stable.tome.raisePrimedFlag()
            UserDefaults.standard.removeObject(forKey: LedgerDictKey.pushURL)
            
            return .finalize(needsConsent ? .askConsent : .unfurlScroll)
        } catch let mishap as LedgerMishap {
            return .stumbled(mishap)
        } catch {
            return .stumbled(.runnerLost(stage: "vellumDispatch"))
        }
    }
}
