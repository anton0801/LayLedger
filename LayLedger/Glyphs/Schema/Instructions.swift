import Foundation

final class TomeContext {
    var ledger: Ledger
    let stable: ScribeStable
    
    init(ledger: Ledger, stable: ScribeStable) {
        self.ledger = ledger
        self.stable = stable
    }
}

enum InstructionResult {
    case skip
    case advance
    case finalize(ScrollOutcome)
    case stumbled(LedgerMishap)
}

protocol Instruction: AnyObject {
    var opcode: String { get }
    func accept(visitor: InstructionVisitor, context: TomeContext) async -> InstructionResult
}

protocol InstructionVisitor: AnyObject {
    func visit(_ instruction: PushSnatchOp, context: TomeContext) async -> InstructionResult
    func visit(_ instruction: ScribblesGateOp, context: TomeContext) async -> InstructionResult
    func visit(_ instruction: OrganicQuillOp, context: TomeContext) async -> InstructionResult
    func visit(_ instruction: VellumDispatchOp, context: TomeContext) async -> InstructionResult
}
