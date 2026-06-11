//
//  ChartViews.swift
//  LayLedger
//
//  Custom, iOS-14-safe charts built from Path / Shape (no Swift Charts dependency).
//

import SwiftUI

struct BarDatum: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    var color: Color = AppColor.accent
}

struct LinePoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - Line chart

struct LineChartView: View {
    let points: [LinePoint]
    var color: Color = AppColor.accent
    var fill: Bool = true
    var height: CGFloat = 160
    var valueSuffix: String = ""

    @State private var progress: CGFloat = 0

    var body: some View {
        let values = points.map { $0.value }
        let maxV = max(values.max() ?? 1, 1)
        let minV = min(values.min() ?? 0, 0)
        let range = max(maxV - minV, 1)

        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let stepX = points.count > 1 ? w / CGFloat(points.count - 1) : w
                let coords: [CGPoint] = points.enumerated().map { idx, p in
                    let x = points.count > 1 ? CGFloat(idx) * stepX : w / 2
                    let y = h - CGFloat((p.value - minV) / range) * h
                    return CGPoint(x: x, y: y)
                }

                ZStack {
                    // gridlines
                    ForEach(0..<3) { i in
                        let y = h * CGFloat(i) / 2
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(AppColor.border, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    }

                    if fill, coords.count > 1 {
                        Path { p in
                            p.move(to: CGPoint(x: coords[0].x, y: h))
                            p.addLine(to: coords[0])
                            for c in coords.dropFirst() { p.addLine(to: c) }
                            p.addLine(to: CGPoint(x: coords.last!.x, y: h))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [color.opacity(0.30), color.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(Double(progress))
                    }

                    if coords.count > 1 {
                        Path { p in
                            p.move(to: coords[0])
                            for c in coords.dropFirst() { p.addLine(to: c) }
                        }
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(Array(coords.enumerated()), id: \.offset) { _, c in
                        Circle().fill(AppColor.card)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(color, lineWidth: 2))
                            .position(c)
                            .opacity(Double(progress))
                    }
                }
            }
            .frame(height: height)

            HStack {
                ForEach(Array(points.enumerated()), id: \.offset) { idx, p in
                    if idx == 0 || idx == points.count - 1 || idx == points.count / 2 {
                        Text(p.label).font(.ll(10, .medium)).foregroundColor(AppColor.textDisabled)
                        if idx != points.count - 1 { Spacer() }
                    }
                }
            }
        }
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
        }
        .onDisappear { progress = 0 }
    }
}

// MARK: - Bar chart

struct BarChartView: View {
    let bars: [BarDatum]
    var height: CGFloat = 170
    var showValues: Bool = true

    @State private var animate = false

    var body: some View {
        let maxV = max(bars.map { $0.value }.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(bars) { bar in
                VStack(spacing: 6) {
                    if showValues {
                        Text(trimmed(bar.value))
                            .font(.ll(11, .bold))
                            .foregroundColor(AppColor.textSecondary)
                            .opacity(animate ? 1 : 0)
                    }
                    GeometryReader { geo in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [bar.color, bar.color.opacity(0.65)],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(height: animate ? max(4, geo.size.height * CGFloat(bar.value / maxV)) : 0)
                        }
                    }
                    Text(bar.label)
                        .font(.ll(10, .medium))
                        .foregroundColor(AppColor.textDisabled)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
        .onAppear {
            animate = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { animate = true }
        }
        .onDisappear { animate = false }
    }

    private func trimmed(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

// MARK: - Split bar (sold vs kept)

struct SplitBar: View {
    let sold: Int
    let kept: Int
    var body: some View {
        let total = max(sold + kept, 1)
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.tealGradient)
                        .frame(width: geo.size.width * CGFloat(sold) / CGFloat(total))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.accentGradient)
                        .frame(width: geo.size.width * CGFloat(kept) / CGFloat(total))
                }
            }
            .frame(height: 18)
            HStack(spacing: 16) {
                legend(color: AppColor.teal, title: "Sold", value: sold)
                legend(color: AppColor.accent, title: "Kept", value: kept)
                Spacer()
            }
        }
    }
    private func legend(color: Color, title: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text("\(title) \(value)").font(.captionM).foregroundColor(AppColor.textSecondary)
        }
    }
}

// MARK: - Ring progress (lay rate)

struct RingProgress: View {
    let percent: Double // 0...100
    var color: Color = AppColor.accent
    var size: CGFloat = 92
    @State private var animated: CGFloat = 0

    var body: some View {
        ZStack {
            Circle().stroke(AppColor.border, lineWidth: 10)
            Circle()
                .trim(from: 0, to: animated)
                .stroke(LinearGradient(colors: [color, color.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(percent.rounded()))").font(.ll(24, .bold)).foregroundColor(AppColor.textPrimary)
                Text("%").font(.ll(11, .semibold)).foregroundColor(AppColor.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animated = 0
            withAnimation(.easeOut(duration: 0.9)) {
                animated = CGFloat(min(max(percent, 0), 100) / 100)
            }
        }
        .onDisappear { animated = 0 }
    }
}
