//
//  LayLedgerApp.swift
//  LayLedger
//
//  App entry point. Injects app-wide state and applies the selected theme.
//

import SwiftUI

@main
struct LayLedgerApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    

    var body: some Scene {
        WindowGroup {
            LaunchView()
        }
    }
}
