//
//  LayLedgerApp.swift
//  LayLedger
//
//  App entry point. Injects app-wide state and applies the selected theme.
//

import SwiftUI

@main
struct LayLedgerApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(theme)
                .preferredColorScheme(theme.colorScheme)
        }
    }
}
