import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @StateObject private var store = DataStore()
    @StateObject private var theme = ThemeManager()

    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
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
        .animation(.easeInOut(duration: 0.45), value: hasCompletedOnboarding)
        .environmentObject(store)
        .environmentObject(theme)
        .preferredColorScheme(theme.colorScheme)
    }
}
