//
//  DataStore.swift
//  LayLedger
//
//  Single source of truth: published collections, CRUD, derived analytics, seeding.
//

import Foundation
import SwiftUI

final class DataStore: ObservableObject {
    @Published var flocks: [Flock] = [] { didSet { save() } }
    @Published var breeds: [Breed] = [] { didSet { save() } }
    @Published var eggEntries: [EggEntry] = [] { didSet { save() } }
    @Published var records: [LedgerRecord] = [] { didSet { save() } }
    @Published var tasks: [TaskItem] = [] { didSet { save() } }
    @Published var photos: [PhotoItem] = [] { didSet { save() } }
    @Published var events: [CalendarEvent] = [] { didSet { save() } }
    @Published var categories: [String] = [] { didSet { save() } }
    @Published var dismissedRecKeys: Set<String> = [] { didSet { save() } }
    @Published var savedRecKeys: Set<String> = [] { didSet { save() } }

    private let persistence = PersistenceService()
    private var isLoaded = false
    private let calendar = Calendar.current

    init() { load() }

    // MARK: - Load / Save

    private func load() {
        if let state = persistence.load() {
            flocks = state.flocks
            breeds = state.breeds
            eggEntries = state.eggEntries
            records = state.records
            tasks = state.tasks
            photos = state.photos
            events = state.events
            categories = state.categories.isEmpty ? Self.defaultCategories : state.categories
            dismissedRecKeys = Set(state.dismissedRecKeys)
            savedRecKeys = Set(state.savedRecKeys)
            if !state.hasSeeded && flocks.isEmpty {
                seedSampleData()
            }
        } else {
            categories = Self.defaultCategories
            seedSampleData()
        }
        isLoaded = true
        save()
    }
    
    private func loaddsa() {
        if let state = persistence.load() {
            flocks = state.flocks
            breeds = state.breeds
            eggEntries = state.eggEntries
            records = state.records
            tasks = state.tasks
            photos = state.photos
            events = state.events
            categories = state.categories.isEmpty ? Self.defaultCategories : state.categories
            dismissedRecKeys = Set(state.dismissedRecKeys)
            savedRecKeys = Set(state.savedRecKeys)
            if !state.hasSeeded && flocks.isEmpty {
                seedSampleData()
            }
        } else {
            categories = Self.defaultCategories
        }
        isLoaded = true
        save()
    }

    private func save() {
        guard isLoaded else { return }
        let state = PersistedState(
            flocks: flocks, breeds: breeds, eggEntries: eggEntries, records: records,
            tasks: tasks, photos: photos, events: events, categories: categories,
            dismissedRecKeys: Array(dismissedRecKeys), savedRecKeys: Array(savedRecKeys),
            hasSeeded: true)
        persistence.save(state)
    }

    var exportURL: URL? {
        persistence.exportFileURL(PersistedState(
            flocks: flocks, breeds: breeds, eggEntries: eggEntries, records: records,
            tasks: tasks, photos: photos, events: events, categories: categories,
            dismissedRecKeys: Array(dismissedRecKeys), savedRecKeys: Array(savedRecKeys),
            hasSeeded: true))
    }

    static let defaultCategories = ["Feed", "Bedding", "Vet / health", "Equipment", "Eggs", "Other"]

    // MARK: - Flock CRUD

    var activeFlocks: [Flock] { flocks.filter { !$0.isArchived } }

    func addFlock(_ flock: Flock) { flocks.insert(flock, at: 0) }

    func updateFlock(_ flock: Flock) {
        if let i = flocks.firstIndex(where: { $0.id == flock.id }) {
            var f = flock; f.updatedAt = Date(); flocks[i] = f
        }
    }

    func toggleArchive(_ flock: Flock) {
        if let i = flocks.firstIndex(where: { $0.id == flock.id }) {
            flocks[i].isArchived.toggle()
            flocks[i].updatedAt = Date()
        }
    }

    func deleteFlock(_ flock: Flock) {
        flocks.removeAll { $0.id == flock.id }
        breeds.removeAll { $0.flockId == flock.id }
        eggEntries.removeAll { $0.flockId == flock.id }
    }

    func flock(_ id: UUID?) -> Flock? { flocks.first { $0.id == id } }

    // MARK: - Breed CRUD

    func breeds(for flock: Flock) -> [Breed] { breeds.filter { $0.flockId == flock.id } }
    func breed(_ id: UUID?) -> Breed? { breeds.first { $0.id == id } }

    func addBreed(_ breed: Breed) {
        breeds.append(breed)
        touch(breed.flockId)
    }
    func updateBreed(_ breed: Breed) {
        if let i = breeds.firstIndex(where: { $0.id == breed.id }) { breeds[i] = breed }
    }
    func deleteBreed(_ breed: Breed) {
        breeds.removeAll { $0.id == breed.id }
        for i in eggEntries.indices where eggEntries[i].breedId == breed.id {
            eggEntries[i].breedId = nil
        }
    }
    func deleteBredsaed(_ breed: Breed) {
        breeds.removeAll { $0.id == breed.id }
        for i in eggEntries.indices where eggEntries[i].breedId == breed.id {
            eggEntries[i].breedId = nil
        }
    }

    private func touch(_ flockId: UUID) {
        if let i = flocks.firstIndex(where: { $0.id == flockId }) { flocks[i].updatedAt = Date() }
    }

    // MARK: - Egg entries

    func addEggEntry(_ entry: EggEntry) {
        eggEntries.append(entry)
        touch(entry.flockId)
        events.append(CalendarEvent(date: entry.date, kind: .eggCollection,
                                    title: "\(entry.eggsCollected) eggs collected"))
    }
    func deleteEggEntry(_ entry: EggEntry) { eggEntries.removeAll { $0.id == entry.id } }

    func todaysEntry(flockId: UUID, breedId: UUID?) -> EggEntry? {
        eggEntries.first {
            $0.flockId == flockId && $0.breedId == breedId && calendar.isDateInToday($0.date)
        }
    }
    func todaysdsaEntry(flockId: UUID, breedId: UUID?) -> EggEntry? {
        eggEntries.first {
            $0.flockId == flockId && $0.breedId == breedId && calendar.isDateInToday($0.date)
        }
    }

    /// Quick +1 — increments today's entry for the given flock/breed, creating one if needed.
    func quickAddEgg(flockId: UUID, breedId: UUID?) {
        if let existing = todaysEntry(flockId: flockId, breedId: breedId),
           let i = eggEntries.firstIndex(where: { $0.id == existing.id }) {
            eggEntries[i].eggsCollected += 1
            eggEntries[i].kept += 1
        } else {
            var entry = EggEntry(flockId: flockId)
            entry.breedId = breedId
            entry.eggsCollected = 1
            entry.kept = 1
            addEggEntry(entry)
        }
    }
    
    func quickAdddsaEgg(flockId: UUID, breedId: UUID?) {
        if let existing = todaysEntry(flockId: flockId, breedId: breedId),
           let i = eggEntries.firstIndex(where: { $0.id == existing.id }) {
            eggEntries[i].eggsCollected += 1
            eggEntries[i].kept += 1
        }
    }

    // MARK: - Ledger records

    func addRecord(_ record: LedgerRecord) {
        records.insert(record, at: 0)
        let kind: CalendarEventKind = record.category == .sale ? .sale :
            (record.category == .expense ? .feedPurchase : .custom)
        events.append(CalendarEvent(date: record.date, kind: kind, title: record.title))
    }
    func updateRecord(_ record: LedgerRecord) {
        if let i = records.firstIndex(where: { $0.id == record.id }) { records[i] = record }
    }
    func deleteRecord(_ record: LedgerRecord) { records.removeAll { $0.id == record.id } }

    func records(_ category: RecordCategory) -> [LedgerRecord] {
        records.filter { $0.category == category }.sorted { $0.date > $1.date }
    }

    // MARK: - Tasks

    func addTask(_ task: TaskItem) { tasks.insert(task, at: 0) }
    func toggleTask(_ task: TaskItem) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) { tasks[i].isDone.toggle() }
    }
    func deleteTask(_ task: TaskItem) { tasks.removeAll { $0.id == task.id } }

    func tasks(_ filter: TaskFilter) -> [TaskItem] {
        let sorted = tasks.sorted { $0.dueDate < $1.dueDate }
        switch filter {
        case .all: return sorted
        case .today: return sorted.filter { calendar.isDateInToday($0.dueDate) && !$0.isDone }
        case .overdue: return sorted.filter { $0.dueDate < calendar.startOfDay(for: Date()) && !$0.isDone }
        case .done: return sorted.filter { $0.isDone }
        }
    }

    // MARK: - Photos

    func addPhoto(_ photo: PhotoItem) { photos.insert(photo, at: 0) }
    func deletePhoto(_ photo: PhotoItem) { photos.removeAll { $0.id == photo.id } }
    func photos(_ category: PhotoCategory?) -> [PhotoItem] {
        guard let category = category else { return photos.sorted { $0.date > $1.date } }
        return photos.filter { $0.category == category }.sorted { $0.date > $1.date }
    }

    // MARK: - Events

    func addEvent(_ event: CalendarEvent) { events.append(event) }
    func events(on day: Date) -> [CalendarEvent] {
        events.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    // MARK: - Analytics

    private var startOfToday: Date { calendar.startOfDay(for: Date()) }

    var totalActiveBirds: Int { activeFlocks.reduce(0) { $0 + $1.birdsCount } }

    func eggs(on day: Date, flockId: UUID? = nil) -> Int {
        eggEntries.filter {
            calendar.isDate($0.date, inSameDayAs: day) && (flockId == nil || $0.flockId == flockId)
        }.reduce(0) { $0 + $1.eggsCollected }
    }

    var todayEggs: Int {
        let activeIDs = Set(activeFlocks.map { $0.id })
        return eggEntries.filter { calendar.isDateInToday($0.date) && activeIDs.contains($0.flockId) }
            .reduce(0) { $0 + $1.eggsCollected }
    }

    var layRateToday: Double {
        guard totalActiveBirds > 0 else { return 0 }
        return min(Double(todayEggs) / Double(totalActiveBirds) * 100, 100)
    }

    func layRate(for flock: Flock) -> Double {
        guard flock.birdsCount > 0 else { return 0 }
        let avg = averageDailyEggs(flockId: flock.id, days: 7)
        return min(avg / Double(flock.birdsCount) * 100, 100)
    }

    func averageDailyEggs(flockId: UUID, days: Int) -> Double {
        var total = 0
        for d in 0..<days {
            if let day = calendar.date(byAdding: .day, value: -d, to: startOfToday) {
                total += eggs(on: day, flockId: flockId)
            }
        }
        return Double(total) / Double(max(days, 1))
    }

    func breedAveragePerDay(_ breed: Breed, days: Int = 7) -> Double {
        var total = 0
        for d in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -d, to: startOfToday) else { continue }
            total += eggEntries.filter {
                $0.breedId == breed.id && calendar.isDate($0.date, inSameDayAs: day)
            }.reduce(0) { $0 + $1.eggsCollected }
        }
        return Double(total) / Double(max(days, 1))
    }

    func breedStatus(_ breed: Breed) -> LayStatus {
        let expectedTotal = breed.expectedEggsPerDay * Double(breed.birdsCount)
        guard expectedTotal > 0 else { return .normal }
        let actual = breedAveragePerDay(breed)
        let ratio = actual / expectedTotal
        switch ratio {
        case 0.9...: return .good
        case 0.7..<0.9: return .normal
        case 0.45..<0.7: return .watch
        default: return .problem
        }
    }

    func eggsByBreedData(days: Int = 7) -> [BarDatum] {
        breeds.compactMap { breed in
            var total = 0
            for d in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: -d, to: startOfToday) else { continue }
                total += eggEntries.filter {
                    $0.breedId == breed.id && calendar.isDate($0.date, inSameDayAs: day)
                }.reduce(0) { $0 + $1.eggsCollected }
            }
            guard total > 0 else { return nil }
            return BarDatum(label: shortName(breed.name), value: Double(total),
                            color: Color(hex: breed.colorHex))
        }
    }

    func soldKeptSplit(days: Int = 30) -> (sold: Int, kept: Int) {
        let cutoff = calendar.date(byAdding: .day, value: -days, to: startOfToday) ?? startOfToday
        let relevant = eggEntries.filter { $0.date >= cutoff }
        return (relevant.reduce(0) { $0 + $1.sold }, relevant.reduce(0) { $0 + $1.kept })
    }

    func dailyEggsTrend(days: Int = 14) -> [LinePoint] {
        (0..<days).reversed().map { d in
            let day = calendar.date(byAdding: .day, value: -d, to: startOfToday) ?? startOfToday
            return LinePoint(label: shortDate(day), value: Double(eggs(on: day)))
        }
    }

    func layRateTrend(days: Int = 14) -> [LinePoint] {
        let birds = max(totalActiveBirds, 1)
        return (0..<days).reversed().map { d in
            let day = calendar.date(byAdding: .day, value: -d, to: startOfToday) ?? startOfToday
            let rate = min(Double(eggs(on: day)) / Double(birds) * 100, 100)
            return LinePoint(label: shortDate(day), value: rate)
        }
    }

    func netProfit(monthsAgo: Int = 0) -> Double {
        let now = Date()
        guard let month = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { return 0 }
        let comps = calendar.dateComponents([.year, .month], from: month)
        return records.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.date)
            return c.year == comps.year && c.month == comps.month
        }.reduce(0) { $0 + $1.amount * $1.category.sign }
    }

    func profitByMonthData(months: Int = 6) -> [BarDatum] {
        (0..<months).reversed().map { m in
            let date = calendar.date(byAdding: .month, value: -m, to: Date()) ?? Date()
            let f = DateFormatter(); f.dateFormat = "MMM"
            let value = netProfit(monthsAgo: m)
            return BarDatum(label: f.string(from: date), value: value,
                            color: value < 0 ? AppColor.problem : AppColor.teal)
        }
    }

    func totalSales() -> Double { records(.sale).reduce(0) { $0 + $1.amount } }
    func totalExpenses() -> Double { records(.expense).reduce(0) { $0 + $1.amount } }

    /// Warnings about lay-rate drops per active flock.
    func layDropWarnings() -> [String] {
        var warnings: [String] = []
        for flock in activeFlocks {
            let recent = averageDailyEggs(flockId: flock.id, days: 3)
            var prevTotal = 0
            for d in 3..<10 {
                if let day = calendar.date(byAdding: .day, value: -d, to: startOfToday) {
                    prevTotal += eggs(on: day, flockId: flock.id)
                }
            }
            let prev = Double(prevTotal) / 7.0
            if prev > 1, recent < prev * 0.8 {
                let drop = Int((1 - recent / prev) * 100)
                warnings.append("\(flock.name): lay down ~\(drop)% vs last week.")
            }
        }
        return warnings
    }

    func generateRecommendations() -> [Recommendation] {
        var recs: [Recommendation] = []
        let warnings = layDropWarnings()
        if !warnings.isEmpty {
            recs.append(Recommendation(
                key: "lay-drop",
                title: "Lay rate is dropping",
                body: "Eggs are down vs last week. Common causes: shorter daylight, molting, stress, heat, or low protein/calcium. " + warnings.joined(separator: " "),
                severity: .problem,
                suggestedTask: "Review feed, water and daylight; add oyster shell"))
        }
        // Cracked egg ratio
        let last14 = eggEntries.filter { $0.date >= (calendar.date(byAdding: .day, value: -14, to: startOfToday) ?? startOfToday) }
        let collected = last14.reduce(0) { $0 + $1.eggsCollected }
        let cracked = last14.reduce(0) { $0 + $1.crackedDiscarded }
        if collected > 0, Double(cracked) / Double(collected) > 0.07 {
            recs.append(Recommendation(
                key: "cracked",
                title: "Too many cracked eggs",
                body: "Over 7% of eggs were cracked or discarded recently. Add crushed oyster shell for stronger shells and collect eggs more often.",
                severity: .watch,
                suggestedTask: "Buy oyster shell / grit"))
        }
        recs.append(Recommendation(
            key: "calcium",
            title: "Keep calcium available",
            body: "Offer crushed oyster shell free-choice so hens self-regulate calcium for strong shells.",
            severity: .normal,
            suggestedTask: "Refill oyster shell feeder"))
        if breeds.isEmpty {
            recs.append(Recommendation(
                key: "add-breeds",
                title: "Add your breeds",
                body: "Add breeds to each flock so Lay Ledger can track per-breed lay rate and tell you which breed pays off.",
                severity: .watch,
                suggestedTask: "Add breeds to flock"))
        }
        recs.append(Recommendation(
            key: "water",
            title: "Check water daily",
            body: "Clean, fresh water has the biggest single impact on lay rate. Verify drinkers aren't empty or frozen.",
            severity: .normal,
            suggestedTask: "Check & clean waterers"))
        return recs.filter { !dismissedRecKeys.contains($0.key) }
    }

    private func shortName(_ name: String) -> String {
        name.count > 8 ? String(name.prefix(7)) + "…" : name
    }

    // MARK: - Seed

    private func seedSampleData() {
        let cal = calendar
        let today = cal.startOfDay(for: Date())

        var flockA = Flock(name: "Backyard Layers")
        flockA.coopLabel = "Coop A"
        flockA.birdsCount = 12
        flockA.startDate = cal.date(byAdding: .month, value: -8, to: today) ?? today
        flockA.notes = "Main laying flock by the garden."

        var flockB = Flock(name: "Heritage Coop")
        flockB.coopLabel = "Coop B"
        flockB.birdsCount = 8
        flockB.startDate = cal.date(byAdding: .month, value: -4, to: today) ?? today
        flockB.notes = "Dual-purpose heritage birds."

        let rir = Breed(flockId: flockA.id, name: "Rhode Island Red", birdsCount: 5, expectedEggsPerDay: 0.82, colorHex: "D97706")
        let leghorn = Breed(flockId: flockA.id, name: "Leghorn", birdsCount: 7, expectedEggsPerDay: 0.88, colorHex: "F59E0B")
        let orpington = Breed(flockId: flockB.id, name: "Orpington", birdsCount: 4, expectedEggsPerDay: 0.62, colorHex: "0D9488")
        let marans = Breed(flockId: flockB.id, name: "Marans", birdsCount: 4, expectedEggsPerDay: 0.66, colorHex: "14B8A6")

        flocks = [flockA, flockB]
        breeds = [rir, leghorn, orpington, marans]

        var entries: [EggEntry] = []
        let seedBreeds = [rir, leghorn, orpington, marans]
        for d in 0..<21 {
            guard let day = cal.date(byAdding: .day, value: -d, to: today) else { continue }
            // Introduce a visible drop in the most recent 4 days.
            let dropFactor = d < 4 ? 0.62 : 1.0
            for breed in seedBreeds {
                let base = Double(breed.birdsCount) * breed.expectedEggsPerDay * dropFactor
                let noise = Double(Int.random(in: -1...1))
                let eggs = max(0, Int((base + noise).rounded()))
                guard eggs > 0 else { continue }
                let cracked = Int.random(in: 0...1) == 0 && eggs > 4 ? 1 : 0
                let usable = max(0, eggs - cracked)
                let sold = breed.flockId == flockA.id ? Int(Double(usable) * 0.6) : Int(Double(usable) * 0.4)
                let kept = usable - sold
                var entry = EggEntry(flockId: breed.flockId)
                entry.date = day
                entry.breedId = breed.id
                entry.eggsCollected = eggs
                entry.crackedDiscarded = cracked
                entry.sold = sold
                entry.kept = kept
                entries.append(entry)
            }
        }
        eggEntries = entries

        records = [
            LedgerRecord(title: "Egg sales — dozen x6", flockId: flockA.id,
                         date: cal.date(byAdding: .day, value: -2, to: today) ?? today,
                         category: .sale, amount: 30, comment: "Neighbors", tag: "Eggs"),
            LedgerRecord(title: "Egg sales — farmers market", flockId: flockA.id,
                         date: cal.date(byAdding: .day, value: -9, to: today) ?? today,
                         category: .sale, amount: 54, comment: "Saturday market", tag: "Eggs"),
            LedgerRecord(title: "Layer feed 25kg", flockId: nil,
                         date: cal.date(byAdding: .day, value: -5, to: today) ?? today,
                         category: .expense, amount: 22.5, comment: "Local co-op", tag: "Feed"),
            LedgerRecord(title: "Oyster shell + grit", flockId: nil,
                         date: cal.date(byAdding: .day, value: -12, to: today) ?? today,
                         category: .expense, amount: 8.0, comment: "", tag: "Feed"),
            LedgerRecord(title: "Pine shavings", flockId: flockB.id,
                         date: cal.date(byAdding: .day, value: -16, to: today) ?? today,
                         category: .expense, amount: 11.0, comment: "Bedding refresh", tag: "Bedding")
        ]

        tasks = [
            TaskItem(title: "Add oyster shell to feeders", dueDate: today),
            TaskItem(title: "Clean waterers", dueDate: cal.date(byAdding: .day, value: -1, to: today) ?? today),
            TaskItem(title: "Order layer feed", dueDate: cal.date(byAdding: .day, value: 3, to: today) ?? today)
        ]

        events = entries.prefix(6).map {
            CalendarEvent(date: $0.date, kind: .eggCollection, title: "\($0.eggsCollected) eggs collected")
        } + records.map {
            CalendarEvent(date: $0.date,
                          kind: $0.category == .sale ? .sale : .feedPurchase,
                          title: $0.title)
        }
    }
}
