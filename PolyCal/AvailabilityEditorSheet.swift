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

    // Single-slot state (hour-only; end is always start + 1 hour)
    @State private var singleDay: Date
    @State private var singleStartHour: Int
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

        _singleDay = State(initialValue: defaultDay)
        _singleStartHour = State(initialValue: defaultHour)

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

                // Single-slot editor (hour-only)
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
                }
            }
        }
    }

    private var singleSection: some View {
        Section("Single Slot") {
            DatePicker("Day", selection: $singleDay, displayedComponents: .date)

            HourPickerRow(title: "Start Hour", hour: $singleStartHour)

            HStack {
                Text("End")
                Spacer()
                Text(hourLabel((singleStartHour + 1) % 24))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("End hour \(hourLabel((singleStartHour + 1) % 24))")
        }
    }

    private var recurringSection: some View {
        Group {
            Section("Recurring") {
                Toggle("Recurring", isOn: $recurringEnabled)

                if recurringEnabled {
                    VStack(alignment: .center, spacing: 12) {
                        Text("Days of Week")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Single-line, centered weekday chips
                        FlexibleWeekdayChips(
                            selected: $selectedWeekdays,
                            weekdaySymbols: Calendar.current.shortWeekdaySymbols
                        )
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Common daily window
                        HourPickerRow(title: "Daily Start", hour: $recurringStartHour)
                        HourPickerRow(title: "Daily End", hour: $recurringEndHour)
                            .onChange(of: recurringEndHour) { _, newValue in
                                if newValue <= recurringStartHour {
                                    recurringEndHour = min(recurringStartHour + 1, 23)
                                }
                            }
                            .onChange(of: recurringStartHour) { _, newValue in
                                if recurringEndHour <= newValue {
                                    recurringEndHour = min(newValue + 1, 23)
                                }
                            }

                        // Date range with "Ongoing"
                        DatePicker("Start Date", selection: Binding<Date>(
                            get: { bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay) },
                            set: { bulkStartDate = $0 }
                        ), displayedComponents: .date)

                        Toggle("Ongoing", isOn: $recurringOngoing)
                            .onChange(of: recurringOngoing) { _, on in
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
                    .frame(maxWidth: .infinity, alignment: .center)
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

    private var recurringDisabled: Bool {
        guard recurringEnabled else { return false }
        if selectedWeekdays.isEmpty { return true }
        if recurringEndHour <= recurringStartHour { return true }
        let start = bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay)
        if let end = bulkEndDate, end < start { return true }
        return false
    }

    private func saveSingle() {
        let cal = Calendar.current
        let start = cal.date(bySettingHour: singleStartHour, minute: 0, second: 0, of: singleDay) ?? singleDay
        let end = cal.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        onSaveSingle(singleDay, start, end, singleStatus)
        dismiss()
    }

    private func applyRecurring() {
        // Map to backend-supported single daily window, fixed 60-minute duration
        let startDateToUse = bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay)
        let endDateToUse = recurringOngoing ? nil : bulkEndDate

        onSaveOngoing(startDateToUse, endDateToUse, recurringStartHour, recurringEndHour, 60)
        dismiss()
    }

    private func hourLabel(_ hour: Int) -> String {
        let comps = DateComponents(calendar: Calendar.current, hour: hour)
        let date = comps.date ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }
}

// A single-line, centered row of weekday chips (abbreviated) supporting multi-select.
// Uses Calendar.shortWeekdaySymbols (Sunday-first).
private struct FlexibleWeekdayChips: View {
    @Binding var selected: Set<Int> // 0...6 => Sunday...Saturday
    let weekdaySymbols: [String]

    var body: some View {
        HStack(spacing: 6) {
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isOn ? .white : .primary)
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekdaySymbols[index])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func shortSymbol(_ index: Int) -> String {
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

