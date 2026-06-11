//
//  CalendarView.swift
//  LayLedger
//
//  Month calendar marking egg collections, sales and feed purchases.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: DataStore
    @State private var month: Date = Date()
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var showAdd = false

    private let cal = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                monthHeader
                weekdayRow
                grid
                legend
                dayEvents
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Calendar", displayMode: .inline)
        .navigationBarItems(trailing: HStack(spacing: 16) {
            Button("Today") { goToday() }
                .font(.ll(14, .semibold)).foregroundColor(AppColor.accentActive)
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.ll(17, .semibold)).foregroundColor(AppColor.accentActive)
            }
        })
        .sheet(isPresented: $showAdd) {
            AddEventView(date: selectedDay).environmentObject(store)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.ll(16, .bold)).foregroundColor(AppColor.accentActive)
            }
            Spacer()
            Text(monthTitle).font(.ll(18, .bold)).foregroundColor(AppColor.textPrimary)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.ll(16, .bold)).foregroundColor(AppColor.accentActive)
            }
        }
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                Text(s).font(.ll(12, .bold)).foregroundColor(AppColor.textDisabled)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let days = monthDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day = day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let kinds = eventKinds(on: day)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDay = day }
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.ll(14, .semibold))
                    .foregroundColor(isSelected ? AppColor.onAccent : AppColor.textPrimary)
                HStack(spacing: 3) {
                    ForEach(Array(kinds.prefix(3).enumerated()), id: \.offset) { _, kind in
                        Circle().fill(isSelected ? AppColor.onAccent : kind.color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                ZStack {
                    if isSelected { RoundedRectangle(cornerRadius: 12).fill(AppColor.accent) }
                    else if isToday { RoundedRectangle(cornerRadius: 12).fill(AppColor.accent.opacity(0.14)) }
                }
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(CalendarEventKind.allCases, id: \.self) { kind in
                HStack(spacing: 5) {
                    Circle().fill(kind.color).frame(width: 8, height: 8)
                    Text(kind.title).font(.ll(10, .medium)).foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayEvents: some View {
        let events = store.events(on: selectedDay)
        return VStack(alignment: .leading, spacing: 10) {
            Text(mediumDate(selectedDay)).font(.cardTitle).foregroundColor(AppColor.textPrimary)
            if events.isEmpty {
                Card {
                    Text("No events on this day.").font(.bodyM).foregroundColor(AppColor.textSecondary)
                }
            } else {
                ForEach(events) { event in
                    Card {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(event.kind.color.opacity(0.16)).frame(width: 38, height: 38)
                                Image(systemName: event.kind.icon).foregroundColor(event.kind.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary)
                                Text(event.kind.title).font(.captionM).foregroundColor(AppColor.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: helpers

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    private func eventKinds(on day: Date) -> [CalendarEventKind] {
        var seen: [CalendarEventKind] = []
        for e in store.events where cal.isDate(e.date, inSameDayAs: day) {
            if !seen.contains(e.kind) { seen.append(e.kind) }
        }
        return seen
    }

    private func monthDays() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let weekday = cal.component(.weekday, from: first) - 1 // 0 = Sunday
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        var result: [Date?] = Array(repeating: nil, count: weekday)
        for d in 0..<count {
            if let day = cal.date(byAdding: .day, value: d, to: first) {
                result.append(cal.startOfDay(for: day))
            }
        }
        return result
    }

    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut) { month = m }
        }
    }

    private func goToday() {
        withAnimation(.easeInOut) {
            month = Date()
            selectedDay = cal.startOfDay(for: Date())
        }
    }
}

struct AddEventView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode

    @State var date: Date
    @State private var title = ""
    @State private var kind: CalendarEventKind = .custom
    @State private var showError = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    LabeledTextField(label: "Event", placeholder: "e.g. Clean coop", text: $title, icon: "calendar")
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type").font(.captionM).foregroundColor(AppColor.textSecondary)
                            Menu {
                                ForEach(CalendarEventKind.allCases, id: \.self) { k in
                                    Button(k.title) { kind = k }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: kind.icon).foregroundColor(kind.color)
                                    Text(kind.title).font(.bodyM).foregroundColor(AppColor.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").foregroundColor(AppColor.textDisabled)
                                }
                            }
                        }
                    }
                    Card(padding: 0) {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .accentColor(AppColor.accentActive).foregroundColor(AppColor.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                    }
                    LLButton(title: "Add Event", icon: "checkmark") { save() }
                    if showError {
                        Text("Enter an event title.").font(.captionM).foregroundColor(AppColor.problem)
                    }
                }
                .padding(18)
            }
            .background(AppColor.bgGradient.ignoresSafeArea())
            .navigationBarTitle("Add Event", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { showError = true }; return }
        store.addEvent(CalendarEvent(date: date, kind: kind, title: trimmed))
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
