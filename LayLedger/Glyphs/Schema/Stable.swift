import Foundation

final class ScribeStable {
    let tome: Tome
    let tracer: Tracer
    let quartermaster: Quartermaster
    let sentry: Sentry
    
    init(tome: Tome, tracer: Tracer, quartermaster: Quartermaster, sentry: Sentry) {
        self.tome = tome
        self.tracer = tracer
        self.quartermaster = quartermaster
        self.sentry = sentry
    }
    
    static func productionStable() -> ScribeStable {
        ScribeStable(
            tome: JSONTome(),
            tracer: AppsFlyerTracer(),
            quartermaster: HTTPQuartermaster(),
            sentry: NotificationSentry()
        )
    }
}

@MainActor
final class Paddock {
    
    static let shared = Paddock()
    
    private lazy var stableInstance: ScribeStable = ScribeStable.productionStable()
    private lazy var interpreterInstance: TomeInterpreter = TomeInterpreter(stable: stableInstance)
    
    private init() {}
    
    func provideStable() -> ScribeStable {
        stableInstance
    }
    
    func provideInterpreter() -> TomeInterpreter {
        interpreterInstance
    }
}
