//
//  OnboardingView.swift
//  LayLedger
//
//  Three onboarding pages, each with a unique interactive element.
//  Looping animations are reset in .onDisappear.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var isVisible = true

    var body: some View {
        ZStack {
            AppColor.bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: Skip
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.ll(15, .semibold))
                        .foregroundColor(AppColor.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .padding(.top, 8)

                TabView(selection: $page) {
                    OnboardingBurstPage(isVisible: $isVisible)
                        .tag(0)
                    OnboardingDragPage()
                        .tag(1)
                    OnboardingParallaxPage()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == page ? AppColor.accent : AppColor.borderStrong)
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.bottom, 18)

                // Controls
                HStack(spacing: 12) {
                    if page > 0 {
                        LLButton(title: "Back", kind: .ghost, fullWidth: false) {
                            withAnimation { page -= 1 }
                        }
                    }
                    LLButton(title: page == 2 ? "Get Started" : "Next",
                             icon: page == 2 ? "checkmark" : "arrow.right") {
                        if page < 2 { withAnimation { page += 1 } } else { finish() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func finish() {
        isVisible = false
        onFinish()
    }
}

// MARK: - Page scaffold

private struct OnboardingScene<Illustration: View>: View {
    let title: String
    let subtitle: String
    let hint: String
    let illustration: Illustration

    init(title: String, subtitle: String, hint: String, @ViewBuilder illustration: () -> Illustration) {
        self.title = title
        self.subtitle = subtitle
        self.hint = hint
        self.illustration = illustration()
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)
            illustration
                .frame(height: 280)
                .frame(maxWidth: .infinity)
            VStack(spacing: 10) {
                Text(title)
                    .font(.ll(26, .bold))
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.bodyM)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Label(hint, systemImage: "hand.tap.fill")
                    .font(.ll(12, .semibold))
                    .foregroundColor(AppColor.accentActive)
                    .padding(.top, 4)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Page 1: tap to burst

private struct BurstInstance: Identifiable { let id = UUID() }

private struct OnboardingBurstPage: View {
    @Binding var isVisible: Bool
    @State private var bursts: [BurstInstance] = []
    @State private var pop = false

    var body: some View {
        OnboardingScene(
            title: "Understand the problem",
            subtitle: "Hard to know how many eggs hens really lay — counts get guessed “by eye”.",
            hint: "Tap the egg to collect"
        ) {
            ZStack {
                Circle()
                    .fill(AppColor.accent.opacity(0.12))
                    .frame(width: 220, height: 220)

                ForEach(bursts) { burst in
                    BurstView()
                        .id(burst.id)
                }

                EggShape()
                    .fill(AppColor.accentGradient)
                    .frame(width: 120, height: 156)
                    .overlay(
                        VStack(spacing: 10) {
                            ForEach(0..<3) { _ in
                                Capsule().fill(Color.white.opacity(0.5)).frame(width: 54, height: 4)
                            }
                        }
                    )
                    .scaleEffect(pop ? 0.9 : 1)
                    .shadow(color: AppColor.yolkGlow, radius: 16, x: 0, y: 8)
                    .onTapGesture { trigger() }
            }
        }
        .onDisappear { bursts.removeAll() }
    }

    private func trigger() {
        guard isVisible else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pop = false }
        }
        let instance = BurstInstance()
        bursts.append(instance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            bursts.removeAll { $0.id == instance.id }
        }
    }
}

private struct BurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
}

private struct BurstView: View {
    @State private var go = false
    private let particles: [BurstParticle] = (0..<12).map { i in
        BurstParticle(angle: Double(i) / 12 * 360,
                      distance: CGFloat.random(in: 80...150),
                      size: CGFloat.random(in: 12...22))
    }
    var body: some View {
        ZStack {
            ForEach(particles) { p in
                EggShape()
                    .fill(AppColor.accentSoft)
                    .frame(width: p.size, height: p.size * 1.3)
                    .offset(x: go ? cos(p.angle * .pi / 180) * p.distance : 0,
                            y: go ? sin(p.angle * .pi / 180) * p.distance : 0)
                    .opacity(go ? 0 : 1)
                    .scaleEffect(go ? 0.3 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { go = true } }
    }
}

// MARK: - Page 2: drag token between baskets

private struct OnboardingDragPage: View {
    @State private var offset: CGSize = .zero
    @State private var leftCount = 4
    @State private var rightCount = 2
    @State private var landedRight = false

    var body: some View {
        OnboardingScene(
            title: "Track everything",
            subtitle: "Keep egg counts and money together — sold vs kept, in one tidy place.",
            hint: "Drag the egg into a basket"
        ) {
            HStack {
                basket(title: "Kept", count: leftCount, color: AppColor.accent)
                Spacer()
                basket(title: "Sold", count: rightCount, color: AppColor.teal)
            }
            .overlay(
                EggShape()
                    .fill(AppColor.accentGradient)
                    .frame(width: 50, height: 64)
                    .shadow(color: AppColor.yolkGlow, radius: 10, x: 0, y: 6)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in offset = value.translation }
                            .onEnded { value in
                                if value.translation.width > 60 {
                                    rightCount += 1
                                    landedRight = true
                                } else if value.translation.width < -60 {
                                    leftCount += 1
                                }
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    offset = .zero
                                }
                            }
                    )
            )
            .padding(.horizontal, 30)
        }
    }

    private func basket(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(color.opacity(0.14))
                    .frame(width: 110, height: 110)
                Image(systemName: "basket.fill")
                    .font(.ll(40, .bold))
                    .foregroundColor(color)
            }
            Text("\(title): \(count)")
                .font(.ll(15, .semibold))
                .foregroundColor(AppColor.textPrimary)
        }
    }
}

// MARK: - Page 3: drag-driven parallax

private struct OnboardingParallaxPage: View {
    @State private var drag: CGSize = .zero

    var body: some View {
        OnboardingScene(
            title: "Get better results",
            subtitle: "Use clear logs, reports and reminders to see which breed pays off.",
            hint: "Drag the scene to explore depth"
        ) {
            ZStack {
                // Back layer — sky glow
                Circle()
                    .fill(AppColor.tealGlow)
                    .frame(width: 200, height: 200)
                    .offset(x: drag.width * 0.05 - 40, y: -40 + drag.height * 0.05)

                // Mid layer — report card
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lay rate").font(.captionM).foregroundColor(AppColor.textSecondary)
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach([0.4, 0.7, 0.55, 0.85, 0.95], id: \.self) { h in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColor.tealGradient)
                                    .frame(width: 16, height: CGFloat(h) * 70)
                            }
                        }
                    }
                }
                .frame(width: 180)
                .offset(x: drag.width * 0.14, y: drag.height * 0.10)

                // Front layer — floating eggs
                Group {
                    EggShape().fill(AppColor.accentGradient).frame(width: 40, height: 52)
                        .offset(x: -90 + drag.width * 0.28, y: 70 + drag.height * 0.22)
                        .shadow(color: AppColor.yolkGlow, radius: 8)
                    EggShape().fill(AppColor.accentGradient).frame(width: 30, height: 40)
                        .offset(x: 95 + drag.width * 0.34, y: -70 + drag.height * 0.30)
                        .shadow(color: AppColor.yolkGlow, radius: 8)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { drag = $0.translation }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { drag = .zero }
                    }
            )
        }
    }
}
