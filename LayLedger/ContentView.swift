//
//  ContentView.swift
//  LayLedger
//
//  Root coordinator: Splash → Onboarding (first launch only) → Main app.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                LaunchView(isActive: $showSplash)
                    .transition(.opacity)
            } else if !hasCompletedOnboarding {
                OnboardingView(onFinish: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        hasCompletedOnboarding = true
                    }
                })
                .transition(.asymmetric(insertion: .opacity,
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showSplash)
        .animation(.easeInOut(duration: 0.45), value: hasCompletedOnboarding)
    }
}
