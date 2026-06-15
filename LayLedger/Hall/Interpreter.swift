import Foundation
import Combine

@MainActor
final class TomeInterpreter {
    
    private var ledger: Ledger = Ledger()
    private var loaded: Bool = false
    
    let seal = ProgramSeal()
    
    private let stable: ScribeStable
    private let visitor: InstructionVisitor
    
    private let outcomeSubject = PassthroughSubject<ScrollOutcome, Never>()
    var outcomePublisher: AnyPublisher<ScrollOutcome, Never> {
        outcomeSubject.eraseToAnyPublisher()
    }
    
    private var consentTask: Task<Void, Never>?
    
    init(stable: ScribeStable) {
        self.stable = stable
        self.visitor = ExecutionVisitor()
    }
    
    private func ensureLoaded() {
        guard !loaded else { return }
        let archive = stable.tome.excavate()
        ledger = Ledger.revive(from: archive)
        loaded = true
    }
    
    func loadTome() {
        ensureLoaded()
    }
    
    func absorbScribbles(_ raw: [String: Any]) {
        ensureLoaded()
        let mapped = raw.mapValues { "\($0)" }
        ledger.scribbles = mapped
        stable.tome.archive(ledger.crystallize())
    }
    
    func absorbGlints(_ raw: [String: Any]) {
        ensureLoaded()
        let mapped = raw.mapValues { "\($0)" }
        ledger.glints = mapped
        stable.tome.archive(ledger.crystallize())
    }
    
    func interpret() async {
        ensureLoaded()
        guard !seal.isSealed else { return }
        
        let program: [Instruction] = [
            PushSnatchOp(),
            ScribblesGateOp(),
            OrganicQuillOp(),
            VellumDispatchOp()
        ]
        
        let context = TomeContext(ledger: ledger, stable: stable)
        
        for instruction in program {
            if seal.isSealed {
                ledger = context.ledger
                return
            }
            
            let result = await instruction.accept(visitor: visitor, context: context)
            
            switch result {
            case .skip, .advance:
                continue
            case .finalize(let outcome):
                ledger = context.ledger
                if case .dormant = outcome {
                    outcomeSubject.send(.dormant)
                    return
                }
                if seal.trySeal() {
                    outcomeSubject.send(outcome)
                }
                return
            case .stumbled:
                ledger = context.ledger
                if seal.trySeal() {
                    outcomeSubject.send(.stricken)
                }
                return
            }
        }
        
        ledger = context.ledger
    }
    
    func signConsent(accepted: @escaping () -> Void) {
        ensureLoaded()
        consentTask = Task { [weak self] in
            guard let self = self else { return }
            
            let granted = await self.stable.sentry.challenge()
            let now = Date()
            
            self.ledger.consentSigned = granted
            self.ledger.consentVoided = !granted
            self.ledger.consentInkedAt = now
            
            self.stable.tome.archive(self.ledger.crystallize())
            
            if granted {
                self.stable.sentry.wireSummoner()
            }
            
            self.outcomeSubject.send(.unfurlScroll)
            accepted()
        }
    }
    
    func deferConsent() {
        ensureLoaded()
        let now = Date()
        ledger.consentInkedAt = now
        stable.tome.archive(ledger.crystallize())
        outcomeSubject.send(.unfurlScroll)
    }
    
    func reportTimeUp() -> Bool {
        return seal.trySeal()
    }
}
