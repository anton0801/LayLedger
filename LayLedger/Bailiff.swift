import Foundation
import Combine

@MainActor
final class LayLedgerBailiff: ObservableObject {
    
    @Published var navigateToMain = false {
        didSet {
            if navigateToMain {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }
    
    @Published var navigateToWeb = false {
        didSet {
            if navigateToWeb {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }
    
    @Published var showPermissionPrompt = false
    @Published var showOfflineView = false
    
    private let interpreter: TomeInterpreter
    private var cancellables = Set<AnyCancellable>()
    private var deadlineTask: Task<Void, Never>?
    
    private var uiLocked: Bool = false
    
    init() {
        self.interpreter = Paddock.shared.provideInterpreter()
        bindOutcomes()
    }
    
    deinit {
        deadlineTask?.cancel()
    }
    
    private func bindOutcomes() {
        interpreter.outcomePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] outcome in
                self?.handleOutcome(outcome)
            }
            .store(in: &cancellables)
    }
    
    func ignite() {
        interpreter.loadTome()
        armDeadline()
    }
    
    func ingestAttribution(_ data: [String: Any]) {
        Task {
            interpreter.absorbScribbles(data)
            await interpreter.interpret()
        }
    }
    
    func ingestDeeplinks(_ data: [String: Any]) {
        interpreter.absorbGlints(data)
    }
    
    func acceptConsent() {
        interpreter.signConsent {
            self.showPermissionPrompt = false
        }
    }
    
    func skipConsent() {
        showPermissionPrompt = false
        interpreter.deferConsent()
    }
    
    func networkConnectivityChanged(_ connected: Bool) {
        showOfflineView = !connected
    }
    
    private func handleOutcome(_ outcome: ScrollOutcome) {
        guard !uiLocked else { return }
        
        switch outcome {
        case .dormant:
            break
        case .askConsent:
            showPermissionPrompt = true
        case .unfurlScroll:
            navigateToWeb = true
        case .stricken:
            navigateToMain = true
        }
    }
    
    private func armDeadline() {
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            
            guard let self = self else { return }
            
            let shouldFire = self.interpreter.reportTimeUp()
            if shouldFire {
                self.handleOutcome(.stricken)
            }
        }
    }
}
