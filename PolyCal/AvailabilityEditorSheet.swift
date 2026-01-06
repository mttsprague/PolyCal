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
    let isAdmin: Bool
    let editingTrainerId: String?
    let onSaveSingle: (Date, Date, Date, TrainerScheduleSlot.Status) -> Void
    let onSaveOngoing: (Date?, Date?, Int?, Int?, Int?, [Int]?) -> Void
    let onBookLesson: (String, Date, Date, String) -> Void // clientId, startTime, endTime, packageId

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
    
    // Admin booking state
    @State private var showBookingSection: Bool = false
    @State private var allClients: [Client] = []
    @State private var selectedClientId: String?
    @State private var clientPackages: [LessonPackage] = []
    @State private var selectedPackageId: String?
    @State private var isLoadingClients: Bool = false
    @State private var isLoadingPackages: Bool = false
    @State private var bookingError: String?

    init(
        defaultDay: Date,
        defaultHour: Int,
        isAdmin: Bool = false,
        editingTrainerId: String? = nil,
        onSaveSingle: @escaping (Date, Date, Date, TrainerScheduleSlot.Status) -> Void,
        onSaveOngoing: @escaping (Date?, Date?, Int?, Int?, Int?, [Int]?) -> Void,
        onBookLesson: @escaping (String, Date, Date, String) -> Void = { _, _, _, _ in }
    ) {
        self.defaultDay = defaultDay
        self.defaultHour = defaultHour
        self.isAdmin = isAdmin
        self.editingTrainerId = editingTrainerId
        self.onSaveSingle = onSaveSingle
        self.onSaveOngoing = onSaveOngoing
        self.onBookLesson = onBookLesson

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
        NavigationView {
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
                
                // Admin booking section
                if isAdmin {
                    adminBookingSection
                }
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
            // Ensure initial values obey the rules on first appearance
            .onAppear {
                snapAndSyncTimes()
                if isAdmin {
                    loadClients()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var singleSection: some View {
        Section("Single Slot") {
            DatePicker("Day", selection: $singleDay, displayedComponents: .date)
                .onChange(of: singleDay) { _, _ in
                    // Re-anchor both times to selected day, keep on-the-hour and end >= start + 1h
                    snapAndSyncTimes(anchorToDay: true)
                }

            // Start time: editable, snaps to the hour; end is kept >= start + 1 hour
            DatePicker("Start", selection: $singleStart, displayedComponents: .hourAndMinute)
                .onChange(of: singleStart) { _, _ in
                    snapAndSyncTimes()
                }

            // End time: editable, snaps to the hour; must be >= start + 1 hour
            DatePicker(
                "End",
                selection: $singleEnd,
                in: (Calendar.current.date(byAdding: .hour, value: 1, to: singleStart) ?? singleStart.addingTimeInterval(3600))...,
                displayedComponents: .hourAndMinute
            )
            .onChange(of: singleEnd) { _, _ in
                snapAndSyncTimes()
            }
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

                        // Common daily window (hour precision)
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
    
    // MARK: - Admin Booking Section
    
    private var adminBookingSection: some View {
        Section {
            Toggle("Book Lesson for Client", isOn: $showBookingSection)
            
            if showBookingSection {
                VStack(alignment: .leading, spacing: 12) {
                    // Client selector
                    if isLoadingClients {
                        HStack {
                            ProgressView()
                            Text("Loading clients...")
                                .foregroundStyle(.secondary)
                        }
                    } else if allClients.isEmpty {
                        Text("No clients found")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Client", selection: $selectedClientId) {
                            Text("Select a client...").tag(nil as String?)
                            ForEach(allClients) { client in
                                Text(client.fullName).tag(Optional(client.id))
                            }
                        }
                        .onChange(of: selectedClientId) { _, newValue in
                            if let clientId = newValue {
                                loadPackagesForClient(clientId)
                            } else {
                                clientPackages = []
                                selectedPackageId = nil
                            }
                        }
                    }
                    
                    // Time editor (defaults to selected slot)
                    DatePicker("Start Time", selection: $singleStart, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: singleStart) { _, _ in
                            // Ensure end is at least 1 hour after start
                            let cal = Calendar.current
                            let minEnd = cal.date(byAdding: .hour, value: 1, to: singleStart) ?? singleStart.addingTimeInterval(3600)
                            if singleEnd < minEnd {
                                singleEnd = minEnd
                            }
                        }
                    
                    DatePicker("End Time", selection: $singleEnd, displayedComponents: [.date, .hourAndMinute])
                    
                    // Package selector
                    if let clientId = selectedClientId {
                        if isLoadingPackages {
                            HStack {
                                ProgressView()
                                Text("Loading packages...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if clientPackages.isEmpty {
                            Text("No available passes for this client")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            Picker("Pass/Package", selection: $selectedPackageId) {
                                Text("Select a pass...").tag(nil as String?)
                                ForEach(availablePackages) { package in
                                    HStack {
                                        Text(package.packageDisplayName)
                                        Spacer()
                                        Text("(\(package.lessonsRemaining) left)")
                                    }
                                    .tag(Optional(package.id))
                                }
                            }
                        }
                    }
                    
                    // Book button
                    Button {
                        bookLesson()
                    } label: {
                        Text("Book Lesson")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canBookLesson ? Color.accentColor : Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!canBookLesson)
                    
                    if let error = bookingError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        } header: {
            Text("Admin: Book for Client")
        }
    }
    
    private var availablePackages: [LessonPackage] {
        clientPackages.filter { !$0.isExpired && $0.lessonsRemaining > 0 }
    }
    
    private var canBookLesson: Bool {
        guard let clientId = selectedClientId,
              let packageId = selectedPackageId,
              !clientId.isEmpty,
              !packageId.isEmpty,
              singleEnd > singleStart else {
            return false
        }
        return true
    }
    
    // MARK: - Admin Booking Functions
    
    private func loadClients() {
        guard let trainerId = editingTrainerId else { return }
        
        isLoadingClients = true
        Task {
            do {
                let clients = try await ClientsRepository().fetchClients(trainerId: trainerId)
                await MainActor.run {
                    self.allClients = clients
                    self.isLoadingClients = false
                }
            } catch {
                await MainActor.run {
                    self.bookingError = "Failed to load clients: \(error.localizedDescription)"
                    self.isLoadingClients = false
                }
            }
        }
    }
    
    private func loadPackagesForClient(_ clientId: String) {
        isLoadingPackages = true
        bookingError = nil
        selectedPackageId = nil
        
        Task {
            do {
                let packages = try await FirestoreService.shared.fetchClientPackages(clientId: clientId)
                await MainActor.run {
                    self.clientPackages = packages
                    self.isLoadingPackages = false
                }
            } catch {
                await MainActor.run {
                    self.bookingError = "Failed to load packages: \(error.localizedDescription)"
                    self.clientPackages = []
                    self.isLoadingPackages = false
                }
            }
        }
    }
    
    private func bookLesson() {
        guard let clientId = selectedClientId,
              let packageId = selectedPackageId else {
            bookingError = "Please select a client and package"
            return
        }
        
        bookingError = nil
        onBookLesson(clientId, singleStart, singleEnd, packageId)
        dismiss()
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
        let startOnDay = roundDownToHour(anchor(time: singleStart, toDay: singleDay, calendar: cal), calendar: cal)
        let minEnd = cal.date(byAdding: .hour, value: 1, to: startOnDay) ?? startOnDay.addingTimeInterval(3600)
        var endOnDay = roundDownToHour(anchor(time: singleEnd, toDay: singleDay, calendar: cal), calendar: cal)
        if endOnDay < minEnd { endOnDay = minEnd }
        onSaveSingle(singleDay, startOnDay, endOnDay, singleStatus)
        dismiss()
    }

    private func applyRecurring() {
        // Send to Cloud Function with 60-minute duration and selected weekdays
        let startDateToUse = bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay)
        let endDateToUse = recurringOngoing ? nil : bulkEndDate
        let daysArray = selectedWeekdays.isEmpty ? nil : Array(selectedWeekdays).sorted()

        onSaveOngoing(startDateToUse, endDateToUse, recurringStartHour, recurringEndHour, 60, daysArray)
        dismiss()
    }

    // MARK: - Helpers

    private func snapAndSyncTimes(anchorToDay: Bool = false) {
        let cal = Calendar.current

        // Optionally re-anchor both to the selected day
        if anchorToDay {
            singleStart = anchor(time: singleStart, toDay: singleDay, calendar: cal)
            singleEnd = anchor(time: singleEnd, toDay: singleDay, calendar: cal)
        }

        // Snap both to the hour
        singleStart = roundDownToHour(singleStart, calendar: cal)
        singleEnd = roundDownToHour(singleEnd, calendar: cal)

        // Ensure end >= start + 1 hour
        let minEnd = cal.date(byAdding: .hour, value: 1, to: singleStart) ?? singleStart.addingTimeInterval(3600)
        if singleEnd < minEnd {
            singleEnd = minEnd
        }
    }

    private func anchor(time: Date, toDay day: Date, calendar cal: Calendar) -> Date {
        let t = cal.dateComponents([.hour, .minute, .second], from: time)
        var d = cal.dateComponents([.year, .month, .day], from: day)
        d.hour = t.hour
        d.minute = t.minute
        d.second = t.second
        return cal.date(from: d) ?? day
    }

    private func roundDownToHour(_ date: Date, calendar cal: Calendar) -> Date {
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
        return cal.date(from: comps) ?? date
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

