import Foundation

final class PushSnatchOp: Instruction {
    let opcode = "pushSnatch"
    func accept(visitor: InstructionVisitor, context: TomeContext) async -> InstructionResult {
        await visitor.visit(self, context: context)
    }
}

final class ScribblesGateOp: Instruction {
    let opcode = "scribblesGate"
    func accept(visitor: InstructionVisitor, context: TomeContext) async -> InstructionResult {
        await visitor.visit(self, context: context)
    }
}

final class OrganicQuillOp: Instruction {
    let opcode = "organicQuill"
    func accept(visitor: InstructionVisitor, context: TomeContext) async -> InstructionResult {
        await visitor.visit(self, context: context)
    }
}

final class VellumDispatchOp: Instruction {
    let opcode = "vellumDispatch"
    func accept(visitor: InstructionVisitor, context: TomeContext) async -> InstructionResult {
        await visitor.visit(self, context: context)
    }
}
