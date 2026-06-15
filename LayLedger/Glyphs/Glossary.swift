import Foundation

enum LedgerGlossary {
    static let appCode = "6779259145"
    static let trackerKey = "q8mxF9ftXWm65MZaUDLFAB"
    static let suiteTome = "group.layledger.tome"
    static let cookiePages = "layledger_pages"
    static let backendVellum = "https://layledger.com/config.php"
    static let logScroll = "📒 [LayLedger]"
    static let tomeFile = "ll_tome_archive.json"
}

enum LedgerDictKey {
    static let routeURL = "ll_route_url"
    static let routeMode = "ll_route_mode"
    static let primed = "ll_primed"
    
    static let pushURL = "temp_url"
    static let fcm = "fcm_token"
    static let push = "push_token"
}

extension Notification.Name {
    static let attributionInkwell = Notification.Name("ConversionDataReceived")
    static let deeplinksInkwell = Notification.Name("deeplink_values")
    static let pushQuill = Notification.Name("LoadTempURL")
}
