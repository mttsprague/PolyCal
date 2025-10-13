//
//  AvailabilityEditorSheet.swift
//  PolyCal
//
//  Created by Assistant on 10/13/25.
//

import SwiftUI

struct AvailabilityEditorSheet: View {
    let defaultDay: Date
    let defaultHour: Int
    let onSaveSingle: (Date, Date, Date, TrainerScheduleSlot.Status) -> Void
    let onSaveOngoing: (Date?, Date?, Int?, Int?, Int?) -> Void

    @Environment(\.dismiss) private var dismiss

    // Single-slot state
    @State private var singleDay: Date
    @State private var singleStart: Date
    @State private var singleEnd: Date
    @State private var singleStatus: TrainerScheduleSlot.Status = .open

    // Recurring toggle and inputs
    @State private var recurringEnabled: Bool = false
    @State private var recurringOngoing: Bool = false
    @State private var bulkStartDate: Date? = nil
    @State private var bulkEndDate: Date? = nil

    // Recurring: selected weekdays and common daily window (hour precision)
    // Weekday indices 0...6 => Sunday...Saturday
    @State private var selectedWeekdays: Set<Int> = []
    @State private var recurringStartHour: Int
    @State private var recurringEndHour: Int

    init(
        defaultDay: Date,
        defaultHour: Int,
        onSaveSingle: @escaping (Date, Date, Date, TrainerScheduleSlot.Status) -> Void,
        onSaveOngoing: @escaping (Date?, Date?, Int?, Int?, Int?) -> Void
    ) {
        self.defaultDay = defaultDay
        self.defaultHour = defaultHour
        self.onSaveSingle = onSaveSingle
        self.onSaveOngoing = onSaveOngoing

        // Initialize state with provided defaults
        let cal = Calendar.current
        _singleDay = State(initialValue: defaultDay)
        let start = cal.date(bySettingHour: defaultHour, minute: 0, second: 0, of: defaultDay) ?? defaultDay
        let end = cal.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        _singleStart = State(initialValue: start)
        _singleEnd = State(initialValue: end)

        _recurringStartHour = State(initialValue: defaultHour)
        _recurringEndHour = State(initialValue: min(defaultHour + 1, 23))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Top choice: Availability vs Unavailability (status for single slot)
                Picker("Status", selection: $singleStatus) {
                    Text("Availability").tag(TrainerScheduleSlot.Status.open)
                    Text("Unavailability").tag(TrainerScheduleSlot.Status.unavailable)
                }
                .pickerStyle(.segmented)

                // Single-slot editor
                singleSection

                // Recurring editor (toggle on/off, then show details)
                recurringSection
            }
            .navigationTitle("Edit Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSingle() }
                        .disabled(singleSaveDisabled)
                }
            }
        }
    }

    private var singleSection: some View {
        Section("Single Slot") {
            DatePicker("Day", selection: $singleDay, displayedComponents: .date)

            DatePicker("Start", selection: $singleStart, displayedComponents: .hourAndMinute)
                .onChange(of: singleStart) { _ in
                    // Keep end > start
                    if singleEnd <= singleStart {
                        singleEnd = Calendar.current.date(byAdding: .minute, value: 30, to: singleStart) ?? singleStart
                    }
                }

            DatePicker("End", selection: $singleEnd, in: singleStart..., displayedComponents: .hourAndMinute)
        }
        .onChange(of: singleDay) { _ in
            // Re-anchor start/end to selected day keeping times
            let cal = Calendar.current
            singleStart = anchor(time: singleStart, toDay: singleDay, calendar: cal)
            singleEnd = max(anchor(time: singleEnd, toDay: singleDay, calendar: cal), singleStart)
        }
    }

    private var recurringSection: some View {
        Group {
            Section("Recurring") {
                Toggle("Recurring", isOn: $recurringEnabled)

                if recurringEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days of Week")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        // Horizontal weekday chips, wrap if needed
                        FlexibleWeekdayChips(
                            selected: $selectedWeekdays,
                            weekdaySymbols: Calendar.current.shortWeekdaySymbols // Sun, Mon, ...
                        )

                        // Common daily window
                        HourPickerRow(title: "Daily Start", hour: $recurringStartHour)
                        HourPickerRow(title: "Daily End", hour: $recurringEndHour)
                            .onChange(of: recurringEndHour) { _ in
                                if recurringEndHour <= recurringStartHour {
                                    recurringEndHour = min(recurringStartHour + 1, 23)
                                }
                            }
                            .onChange(of: recurringStartHour) { _ in
                                if recurringEndHour <= recurringStartHour {
                                    recurringEndHour = min(recurringStartHour + 1, 23)
                                }
                            }

                        // Date range with "Ongoing"
                        DatePicker("Start Date", selection: Binding<Date>(
                            get: { bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay) },
                            set: { bulkStartDate = $0 }
                        ), displayedComponents: .date)

                        Toggle("Ongoing", isOn: $recurringOngoing)
                            .onChange(of: recurringOngoing) { on in
                                if on { bulkEndDate = nil }
                            }

                        if !recurringOngoing {
                            DatePicker("End Date", selection: Binding<Date>(
                                get: {
                                    if let d = bulkEndDate { return d }
                                    // Default to one month after start
                                    let start = bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay)
                                    return Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
                                },
                                set: { bulkEndDate = $0 }
                            ), displayedComponents: .date)
                        }

                        // Action button for recurring
                        Button {
                            applyRecurring()
                        } label: {
                            Text("Apply Recurring")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .disabled(recurringDisabled)
                    }
                }
            }

            if recurringEnabled {
                Section {
                    Text("Recurring creates 60-minute open availability slots on selected weekdays between the start and end dates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var singleSaveDisabled: Bool {
        singleEnd <= singleStart
    }

    private var recurringDisabled: Bool {
        guard recurringEnabled else { return false }
        // Need at least one day selected
        if selectedWeekdays.isEmpty { return true }
        // Validate daily window
        if recurringEndHour <= recurringStartHour { return true }
        // Validate date range
        let start = bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay)
        if let end = bulkEndDate, end < start { return true }
        return false
    }

    private func saveSingle() {
        let cal = Calendar.current
        let startOnDay = anchor(time: singleStart, toDay: singleDay, calendar: cal)
        let endOnDay = anchor(time: singleEnd, toDay: singleDay, calendar: cal)
        onSaveSingle(singleDay, startOnDay, endOnDay, singleStatus)
        dismiss()
    }

    private func applyRecurring() {
        // Map to backend-supported single daily window, fixed 60-minute duration
        let startDateToUse = bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay)
        let endDateToUse = recurringOngoing ? nil : bulkEndDate

        onSaveOngoing(startDateToUse, endDateToUse, recurringStartHour, recurringEndHour, 60)
        dismiss()
    }

    private func anchor(time: Date, toDay day: Date, calendar cal: Calendar) -> Date {
        let t = cal.dateComponents([.hour, .minute, .second], from: time)
        var d = cal.dateComponents([.year, .month, .day], from: day)
        d.hour = t.hour
        d.minute = t.minute
        d.second = t.second
        return cal.date(from: d) ?? day
    }
}

// A flexible row of weekday chips (abbreviated) supporting multi-select.
// Uses Calendar.shortWeekdaySymbols (Sunday-first).
private struct FlexibleWeekdayChips: View {
    @Binding var selected: Set<Int> // 0...6 => Sunday...Saturday
    let weekdaySymbols: [String]

    var body: some View {
        // Wrap in a grid-like flow using LazyVGrid with adaptive columns
        let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                let isOn = selected.contains(index)
                Button {
                    if isOn {
                        selected.remove(index)
                    } else {
                        selected.insert(index)
                    }
                } label: {
                    Text(shortSymbol(index))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? .white : .primary)
                        .padding(.vertical, 8)
                        .frame(minWidth: 44)
                        .background(
                            Capsule().fill(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekdaySymbols[index])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func shortSymbol(_ index: Int) -> String {
        // Use provided short symbols (e.g., "Sun", "Mon", ...)
        let i = max(0, min(6, index))
        return String(weekdaySymbols[i].prefix(3))
    }
}

private struct HourPickerRow: View {
    let title: String
    @Binding var hour: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(hourLabel(h)).tag(h)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let comps = DateComponents(calendar: Calendar.current, hour: hour)
        let date = comps.date ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }
}

private struct OptionalDatePickerRow: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { date != nil },
                set: { newValue in
                    if newValue {
                        if date == nil {
                            date = Calendar.current.startOfDay(for: Date())
                        }
                    } else {
                        date = nil
                    }
                }
            )) {
                Text(title)
            }

            if let current = date {
                DatePicker(
                    "",
                    selection: Binding<Date>(
                        get: { current },
                        set: { newValue in date = newValue }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.leading, 32)
            }
        }
    }
}
