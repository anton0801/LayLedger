//
//  Models.swift
//  LayLedger
//
//  Core data models, enums, app settings and shared formatters.
//

import Foundation
import SwiftUI

// MARK: - Enums

enum RecordCategory: String, Codable, CaseIterable, Identifiable {
    case sale, expense, note

    var id: String { rawValue }
    var title: String {
        switch self {
        case .sale: return "Sale"
        case .expense: return "Expense"
        case .note: return "Note"
        }
    }
    var icon: String {
        switch self {
        case .sale: return "arrow.up.circle.fill"
        case .expense: return "arrow.down.circle.fill"
        case .note: return "note.text"
        }
    }
    var color: Color {
        switch self {
        case .sale: return AppColor.teal
        case .expense: return AppColor.problem
        case .note: return AppColor.accent
        }
    }
    /// Signed contribution to net profit.
    var sign: Double {
        switch self {
        case .sale: return 1
        case .expense: return -1
        case .note: return 0
        }
    }
}

enum EggUnit: String, CaseIterable, Identifiable {
    case eggs, dozen
    var id: String { rawValue }
    var title: String { self == .eggs ? "Eggs" : "Dozen" }
    var shortLabel: String { self == .eggs ? "eggs" : "doz" }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

enum PhotoCategory: String, Codable, CaseIterable, Identifiable {
    case eggs, birds, coop, saleBatch
    var id: String { rawValue }
    var title: String {
        switch self {
        case .eggs: return "Eggs"
        case .birds: return "Birds"
        case .coop: return "Coop"
        case .saleBatch: return "Sale batch"
        }
    }
    var icon: String {
        switch self {
        case .eggs: return "oval.portrait.fill"
        case .birds: return "bird.fill"
        case .coop: return "house.fill"
        case .saleBatch: return "shippingbox.fill"
        }
    }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case all, today, overdue, done
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum LayStatus: String, Codable, CaseIterable {
    case good, normal, watch, problem

    var color: Color {
        switch self {
        case .good: return AppColor.good
        case .normal: return AppColor.teal
        case .watch: return AppColor.watch
        case .problem: return AppColor.problem
        }
    }
    var title: String {
        switch self {
        case .good: return "Good"
        case .normal: return "Stable"
        case .watch: return "Watch"
        case .problem: return "Problem"
        }
    }
    var icon: String {
        switch self {
        case .good: return "arrow.up.right.circle.fill"
        case .normal: return "equal.circle.fill"
        case .watch: return "exclamationmark.triangle.fill"
        case .problem: return "arrow.down.right.circle.fill"
        }
    }
}

enum CalendarEventKind: String, Codable, CaseIterable {
    case eggCollection, sale, feedPurchase, custom
    var title: String {
        switch self {
        case .eggCollection: return "Egg collection"
        case .sale: return "Sale"
        case .feedPurchase: return "Feed / expense"
        case .custom: return "Event"
        }
    }
    var icon: String {
        switch self {
        case .eggCollection: return "oval.portrait.fill"
        case .sale: return "dollarsign.circle.fill"
        case .feedPurchase: return "cart.fill"
        case .custom: return "calendar"
        }
    }
    var color: Color {
        switch self {
        case .eggCollection: return AppColor.accent
        case .sale: return AppColor.teal
        case .feedPurchase: return AppColor.problem
        case .custom: return AppColor.textSecondary
        }
    }
}

// MARK: - Models

struct Flock: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var coopLabel: String = ""
    var birdsCount: Int = 0
    var startDate: Date = Date()
    var notes: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct Breed: Identifiable, Codable, Hashable {
    var id = UUID()
    var flockId: UUID
    var name: String
    var birdsCount: Int = 0
    var expectedEggsPerDay: Double = 0
    var colorHex: String = "F59E0B"
    var photo: Data? = nil
}

struct EggEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var flockId: UUID
    var breedId: UUID? = nil
    var eggsCollected: Int = 0
    var crackedDiscarded: Int = 0
    var sold: Int = 0
    var kept: Int = 0
    var notes: String = ""
}

struct LedgerRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var flockId: UUID? = nil
    var date: Date = Date()
    var category: RecordCategory = .expense
    var amount: Double = 0
    var comment: String = ""
    var tag: String? = nil
    var photo: Data? = nil
}

struct TaskItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var dueDate: Date = Date()
    var isDone: Bool = false
    var notes: String = ""
}

struct PhotoItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var image: Data
    var category: PhotoCategory = .eggs
    var date: Date = Date()
    var caption: String = ""
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var kind: CalendarEventKind = .custom
    var title: String
}

struct Recommendation: Identifiable, Codable, Hashable {
    var key: String
    var id: String { key }
    var title: String
    var body: String
    var severity: LayStatus = .watch
    var suggestedTask: String = ""
}

// MARK: - App Settings access (non-View context)

enum AppSettings {
    static var eggUnit: EggUnit {
        EggUnit(rawValue: UserDefaults.standard.string(forKey: "eggUnit") ?? "eggs") ?? .eggs
    }
    static var currencyCode: String {
        UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
    }
}

// MARK: - Formatters

func formatEggs(_ count: Int) -> String {
    switch AppSettings.eggUnit {
    case .eggs:
        return "\(count)"
    case .dozen:
        let doz = Double(count) / 12.0
        return String(format: doz.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", doz)
    }
}

var eggUnitLabel: String { AppSettings.eggUnit.shortLabel }

func formatMoney(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = AppSettings.currencyCode
    f.maximumFractionDigits = (amount.truncatingRemainder(dividingBy: 1) == 0) ? 0 : 2
    return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
}

func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f.string(from: date)
}

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    return f.string(from: date)
}

func relativeUpdated(_ date: Date) -> String {
    let secs = Date().timeIntervalSince(date)
    if secs < 60 { return "just now" }
    if secs < 3600 { return "\(Int(secs / 60))m ago" }
    if secs < 86400 { return "\(Int(secs / 3600))h ago" }
    return "\(Int(secs / 86400))d ago"
}

let currencyOptions: [(code: String, label: String)] = [
    ("USD", "$ US Dollar"),
    ("EUR", "€ Euro"),
    ("GBP", "£ British Pound"),
    ("RUB", "₽ Russian Ruble"),
    ("UAH", "₴ Ukrainian Hryvnia"),
    ("PLN", "zł Polish Zloty"),
    ("CAD", "$ Canadian Dollar"),
    ("AUD", "$ Australian Dollar"),
    ("INR", "₹ Indian Rupee")
]
