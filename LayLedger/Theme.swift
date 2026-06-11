//
//  Theme.swift
//  LayLedger
//
//  Color palette (light/dark adaptive), typography helpers and the ThemeManager.
//

import SwiftUI
import UIKit

// MARK: - Hex helpers

extension UIColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: UInt64
        switch s.count {
        case 8: (r, g, b, a) = (value >> 24 & 0xFF, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        case 6: (r, g, b, a) = (value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF, 255)
        default: (r, g, b, a) = (255, 255, 255, 255)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension Color {
    init(hex: String) { self.init(UIColor(hex: hex)) }
}

/// Builds a dynamic color that resolves against the active interface style,
/// so `.preferredColorScheme` (driven by ThemeManager) recolors the whole app.
func dynColor(_ light: String, _ dark: String) -> Color {
    Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

// MARK: - Palette

enum AppColor {
    // Backgrounds
    static let bg            = dynColor("FFFBEB", "17140D")
    static let bgSecondary   = dynColor("FEF6D9", "1F1B12")
    static let depth         = dynColor("F5ECCB", "262112")
    static let card          = dynColor("FFFFFF", "221E15")
    static let cardHover     = dynColor("FFFBEB", "2A2417")
    static let border        = dynColor("EBDFB8", "3A3220")
    static let borderStrong  = dynColor("D9C98A", "4A4029")

    // Accents
    static let accent        = dynColor("F59E0B", "F59E0B")
    static let accentActive  = dynColor("D97706", "D97706")
    static let accentSoft    = dynColor("FBBF24", "FBBF24")
    static let onAccent      = Color(hex: "422006")

    static let teal          = dynColor("0D9488", "14B8A6")
    static let tealSoft      = dynColor("14B8A6", "2DD4BF")
    static let tealHi        = dynColor("5EEAD4", "5EEAD4")

    // Status
    static let good          = dynColor("22C55E", "34D27A")
    static let watch         = dynColor("F59E0B", "FBBF24")
    static let problem       = dynColor("EF4444", "F87171")

    // Text
    static let textPrimary   = dynColor("422006", "F5ECCB")
    static let textSecondary = dynColor("78622C", "C9B98A")
    static let textDisabled  = dynColor("A8915C", "8A7A52")

    // Effects
    static let yolkGlow      = Color(hex: "F59E0B").opacity(0.25)
    static let tealGlow      = Color(hex: "0D9488").opacity(0.20)
    static let shadow        = Color(hex: "785A14").opacity(0.10)
    static let onSuccess     = Color.white

    // Gradients
    static var bgGradient: LinearGradient {
        LinearGradient(colors: [bg, bgSecondary, depth],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSoft, accent, accentActive],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var tealGradient: LinearGradient {
        LinearGradient(colors: [tealHi, teal],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Typography

extension Font {
    /// Rounded system font — friendly, on-brand for the app.
    static func ll(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static var titleXL: Font { .ll(30, .bold) }
    static var title: Font { .ll(24, .bold) }
    static var headline: Font { .ll(18, .semibold) }
    static var cardTitle: Font { .ll(17, .semibold) }
    static var bodyM: Font { .ll(15, .regular) }
    static var captionM: Font { .ll(13, .medium) }
    static var stat: Font { .ll(34, .bold) }
}

// MARK: - Theme Manager

final class ThemeManager: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.theme = AppTheme(rawValue: raw) ?? .system
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
