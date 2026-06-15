import SwiftUI
import Combine
import Network

private struct FloatingEgg: Identifiable {
    let id = UUID()
    let x: CGFloat       // 0...1 horizontal position
    let baseY: CGFloat   // 0...1 vertical position
    let size: CGFloat
    let sway: CGFloat
    let duration: Double
    let delay: Double
    let tilt: Double
}

struct LaunchView: View {
    
    @StateObject private var bailiff = LayLedgerBailiff()

    @State private var isVisible = true
    @State private var bgShift = false
    @State private var eggsFloat = false
    @State private var ringPulse = false
    @State private var logoIn = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var titleIn = false
    @State private var exiting = false

    @State private var elapsed: Double = 0
    @State private var networkMonitor = NWPathMonitor()
    @State private var timer: Timer?

    private let eggs: [FloatingEgg] = [
        FloatingEgg(x: 0.16, baseY: 0.30, size: 26, sway: 22, duration: 2.4, delay: 0.0, tilt: 10),
        FloatingEgg(x: 0.82, baseY: 0.24, size: 34, sway: 30, duration: 2.9, delay: 0.3, tilt: -14),
        FloatingEgg(x: 0.30, baseY: 0.70, size: 22, sway: 18, duration: 2.2, delay: 0.6, tilt: 8),
        FloatingEgg(x: 0.70, baseY: 0.74, size: 30, sway: 26, duration: 3.1, delay: 0.15, tilt: -10),
        FloatingEgg(x: 0.50, baseY: 0.18, size: 20, sway: 16, duration: 2.6, delay: 0.45, tilt: 12),
        FloatingEgg(x: 0.10, baseY: 0.82, size: 24, sway: 20, duration: 2.8, delay: 0.2, tilt: -8),
        FloatingEgg(x: 0.90, baseY: 0.60, size: 18, sway: 14, duration: 2.1, delay: 0.5, tilt: 6)
    ]

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack {
                    // LAYER 1 — shifting warm gradient
                    AppColor.bgGradient.ignoresSafeArea()
                    LinearGradient(colors: [AppColor.accentSoft.opacity(0.35), Color(hex: "FEF6D9").opacity(0.0)],
                                   startPoint: bgShift ? .topLeading : .bottomTrailing,
                                   endPoint: bgShift ? .bottomTrailing : .topLeading)
                        .ignoresSafeArea()
                        .opacity(bgShift ? 0.9 : 0.4)
                    
                    NavigationLink(
                        destination: RootView().navigationBarBackButtonHidden(true),
                        isActive: $bailiff.navigateToMain
                    ) { EmptyView() }

                    // LAYER 2 — floating eggs (midground motif)
                    ForEach(eggs) { egg in
                        EggShape()
                            .fill(LinearGradient(colors: [Color.white.opacity(0.9), AppColor.accentSoft.opacity(0.55)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: egg.size, height: egg.size * 1.3)
                            .rotationEffect(.degrees(eggsFloat ? egg.tilt : -egg.tilt))
                            .position(x: egg.x * geo.size.width,
                                      y: egg.baseY * geo.size.height + (eggsFloat ? -egg.sway : egg.sway))
                            .opacity(eggsFloat ? 0.85 : 0.25)
                            .shadow(color: AppColor.yolkGlow, radius: 8)
                            .animation(.easeInOut(duration: egg.duration)
                                        .repeatForever(autoreverses: true)
                                        .delay(egg.delay), value: eggsFloat)
                    }
                    
                    NavigationLink(
                        destination: LayLedgerScrollroom().navigationBarHidden(true),
                        isActive: $bailiff.navigateToWeb
                    ) { EmptyView() }

                    // LAYER 3 — logo + title
                    VStack(spacing: 22) {
                        ZStack {
                            Circle()
                                .fill(AppColor.yolkGlow)
                                .frame(width: 168, height: 168)
                                .scaleEffect(ringPulse ? 1.12 : 0.9)
                                .opacity(ringPulse ? 0.5 : 0.9)
                                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: ringPulse)

                            EggShape()
                                .fill(AppColor.accentGradient)
                                .frame(width: 96, height: 124)
                                .overlay(ledgerLines)
                                .shadow(color: AppColor.yolkGlow, radius: 18, x: 0, y: 10)
                        }
                        .scaleEffect(exiting ? 1.6 : (logoIn ? 1 : 0.5))
                        .opacity(exiting ? 0 : (logoIn ? 1 : 0))

                        VStack(spacing: 6) {
                            Text("Lay Ledger")
                                .font(.ll(34, .bold))
                                .foregroundColor(AppColor.textPrimary)
                            Text("Loading app content")
                                .font(.ll(15, .medium))
                                .foregroundColor(AppColor.textSecondary)
                            Text("Wait when app loads")
                                .font(.ll(12, .medium))
                                .foregroundColor(AppColor.textSecondary)
                        }
                        .opacity(exiting ? 0 : (titleIn ? 1 : 0))
                        .offset(y: titleIn ? 0 : 14)
                    }
                }
            }
            .onAppear { start() }
            .onDisappear { stop() }
            .fullScreenCover(isPresented: $bailiff.showPermissionPrompt) {
                ConsentChamber(bailiff: bailiff)
            }
            .fullScreenCover(isPresented: $bailiff.showOfflineView) {
                OfflineChamber()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var ledgerLines: some View {
        VStack(spacing: 9) {
            ForEach(0..<3) { _ in
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 46, height: 4)
            }
        }
    }

    // MARK: - Coordinator

    private func start() {
        bailiff.ignite()
        wireStreams()
        isVisible = true
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { bgShift = true }
        
        wireNetworkMonitoring()
        
        let t = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { tick in
            guard isVisible else { tick.invalidate(); return }
            elapsed += 0.1

            if elapsed >= 0.6, !eggsFloat {
                ringPulse = true
                eggsFloat = true
            }
            if elapsed >= 1.4, !logoIn {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { logoIn = true }
            }
            if elapsed >= 1.9, !titleIn {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { titleIn = true }
            }
//            if elapsed >= 2.5, !exiting {
//                withAnimation(.easeIn(duration: 0.45)) { exiting = true }
//            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    private func wireNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            Task { @MainActor in
                bailiff.networkConnectivityChanged(path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: .global(qos: .background))
    }
    
    private func stop() {
        isVisible = false
        timer?.invalidate()
        timer = nil
        // Reset all looping/animation state to initial to prevent leaks.
        bgShift = false
        eggsFloat = false
        ringPulse = false
        logoIn = false
        titleIn = false
        exiting = false
        elapsed = 0
    }
    
    
    
    private func wireStreams() {
        NotificationCenter.default.publisher(for: .attributionInkwell)
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { data in
                bailiff.ingestAttribution(data)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .deeplinksInkwell)
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { data in
                bailiff.ingestDeeplinks(data)
            }
            .store(in: &cancellables)
    }
    
}

struct ConsentChamber: View {
    let bailiff: LayLedgerBailiff
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image("lay_wall")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                if geometry.size.width < geometry.size.height {
                    vertView
                } else {
                    horView
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
    
    private var titleText: some View {
        Text("ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS")
            .font(.system(size: 23, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
    }
    
    private var vertView: some View {
        VStack(spacing: 12) {
            Spacer()
            titleText
                .multilineTextAlignment(.center)
            subtitleText
                .multilineTextAlignment(.center)
            actionButtons
        }
        .padding(.bottom, 24)
    }
    
    private var horView: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Spacer()
                titleText
                subtitleText
            }
            Spacer()
            VStack {
                Spacer()
                actionButtons
            }
            Spacer()
        }
        .padding(.bottom, 24)
    }
    
    private var subtitleText: some View {
        Text("STAY TUNED WITH BEST OFFERS FROM\nOUR CASINO")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                bailiff.acceptConsent()
            } label: {
                Image("lay_b")
                    .resizable()
                    .frame(width: 300, height: 55)
            }
            
            Button {
                bailiff.skipConsent()
            } label: {
                Image("lay_sk")
                    .resizable()
                    .frame(width: 270, height: 35)
            }
        }
        .padding(.horizontal, 12)
    }
}

struct OfflineChamber: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image("lay_load")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.9)
                    .blur(radius: 3)
                
                errorView
            }
        }
        .ignoresSafeArea()
    }
    
    private var errorView: some View {
        Image("lay_error")
            .resizable()
            .frame(width: 320, height: 260)
    }
}

#Preview {
    LaunchView()
}
