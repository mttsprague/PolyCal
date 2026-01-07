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
    let onSaveSingle: (Date, Date, Date, TrainerScheduleSlot.Status, Bool) -> Void
    let onSaveOngoing: (Date?, Date?, Int?, Int?, Int?, [Int]?, TrainerScheduleSlot.Status, Bool) -> Void
    let onBookLesson: (String, TimeInterval, TimeInterval, String) -> Void // clientId, startTime, endTime, packageId

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
    
    // Admin: apply unavailability to all trainers
    @State private var applyToAllTrainers: Bool = false
    
    // Main tab selection
    @State private var mainTab: MainTab = .editAvailability
    
    enum MainTab {
        case editAvailability
        case bookLesson
    }
    
    // Admin booking state
    @State private var allClients: [Client] = []
    @State private var selectedClientId: String?
    @State private var clientPackages: [LessonPackage] = []
    @State private var selectedPackageType: String?
    @State private var selectedPackageId: String?
    @State private var isLoadingClients: Bool = false
    @State private var isLoadingPackages: Bool = false
    @State private var isBooking: Bool = false
    @State private var bookingError: String?

    init(
        defaultDay: Date,
        defaultHour: Int,
        isAdmin: Bool = false,
        editingTrainerId: String? = nil,
        onSaveSingle: @escaping (Date, Date, Date, TrainerScheduleSlot.Status) -> Void,
        onSaveOngoing: @escaping (Date?, Date?, Int?, Int?, Int?, [Int]?, TrainerScheduleSlot.Status) -> Void,
        onBookLesson: @escaping (String, TimeInterval, TimeInterval, String) -> Void = { _, _, _, _ in }
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
            VStack(spacing: 0) {
                // Main tab selector (only shown for admin)
                if isAdmin {
                    Picker("Mode", selection: $mainTab) {
                        Text("Edit Availability").tag(MainTab.editAvailability)
                        Text("Book a Lesson").tag(MainTab.bookLesson)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                
                // Content based on selected main tab
                if mainTab == .editAvailability {
                    editAvailabilityContent
                } else {
                    bookLessonContent
                }
            }
            .navigationTitle(mainTab == .editAvailability ? "Edit Availability" : "Book a Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if mainTab == .editAvailability {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveSingle() }
                            .disabled(singleSaveDisabled)
                    }
                }
            }
            .onAppear {
                snapAndSyncTimes()
                if isAdmin {
                    loadClients()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Edit Availability Content
    
    private var editAvailabilityContent: some View {
        Form {
            // Top choice: Availability vs Unavailability (status for single slot)
            Picker("Status", selection: $singleStatus) {
                Text("Availability").tag(TrainerScheduleSlot.Status.open)
                Text("Unavailability").tag(TrainerScheduleSlot.Status.unavailable)
            }
            .pickerStyle(.segmented)
            
            // Admin: Apply to all trainers (only for unavailability)
            if isAdmin && singleStatus == .unavailable {
                Section {
                    Toggle("Apply to all trainers", isOn: $applyToAllTrainers)
                } footer: {
                    Text("When enabled, this unavailability will be applied to all trainers' schedules.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Single-slot editor
            singleSection

            // Recurring editor (toggle on/off, then show details)
            recurringSection
        }
    }
    
    // MARK: - Book Lesson Content
    
    private var bookLessonContent: some View {
        Form {
            Section {
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
                            selectedPackageType = nil
                            selectedPackageId = nil
                        }
                    }
                }
            } header: {
                Text("Select Client")
            }
            
            Section {
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
            } header: {
                Text("Lesson Time")
            }
            
            Section {
                // Package selector with grouped display
                if let clientId = selectedClientId {
                    if isLoadingPackages {
                        HStack {
                            ProgressView()
                            Text("Loading packages...")
                                .foregroundStyle(.secondary)
                        }
                    } else if availablePackages.isEmpty {
                        Text("No available passes for this client")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            // Package type picker - select by type, not individual package
                            Picker("Select Pass Type", selection: $selectedPackageType) {
                                Text("Choose a pass type...").tag(nil as String?)
                                ForEach(["private", "2_athlete", "3_athlete", "class_pass"], id: \.self) { type in
                                    let count = totalPassesForType(type)
                                    if count > 0 {
                                        Text("\(packageTypeName(type)) (\(count) available)")
                                            .tag(Optional(type))
                                    }
                                }
                            }
                            .onChange(of: selectedPackageType) { _, newType in
                                // When type is selected, automatically pick the best available package of that type
                                // Priority: earliest expiration date (if set), then oldest purchase date
                                if let type = newType {
                                    let packagesOfType = packagesByType[type]?.filter { $0.lessonsRemaining > 0 && !$0.isExpired } ?? []
                                    
                                    let sortedPackages = packagesOfType.sorted { pkg1, pkg2 in
                                        // Sort by expiration date first (if both have one, earliest first)
                                        if let exp1 = pkg1.expirationDate, let exp2 = pkg2.expirationDate {
                                            return exp1 < exp2
                                        } else if pkg1.expirationDate != nil {
                                            return true // pkg1 has expiration, prioritize it
                                        } else if pkg2.expirationDate != nil {
                                            return false // pkg2 has expiration, prioritize it
                                        }
                                        // If neither has expiration or both don't, use oldest purchase date
                                        return pkg1.purchaseDate < pkg2.purchaseDate
                                    }
                                    
                                    selectedPackageId = sortedPackages.first?.id
                                } else {
                                    selectedPackageId = nil
                                }
                            }
                        }
                    }
                } else {
                    Text("Please select a client first")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } header: {
                Text("Lesson Package")
            }
            
            Section {
                Button {
                    Task {
                        await bookLesson()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isBooking {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isBooking ? "Booking..." : "Book Lesson")
                        Spacer()
                    }
                }
                .listRowBackground((canBookLesson && !isBooking) ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .disabled(!canBookLesson || isBooking)
                
                if let error = bookingError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
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
                    Text("Recurring creates 60-minute slots on selected weekdays between the start and end dates with the chosen status (Availability or Unavailability).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var availablePackages: [LessonPackage] {
        clientPackages.filter { !$0.isExpired && $0.lessonsRemaining > 0 }
    }
    
    private var packagesByType: [String: [LessonPackage]] {
        Dictionary(grouping: availablePackages) { $0.packageType }
    }
    
    private func packageTypeName(_ type: String) -> String {
        switch type {
        case "private": return "Private Lesson Passes"
        case "2_athlete": return "2-Athlete Passes"
        case "3_athlete": return "3-Athlete Passes"
        case "class_pass": return "Class Passes"
        default: return type
        }
    }
    
    private func totalPassesForType(_ type: String) -> Int {
        packagesByType[type]?.reduce(0) { $0 + $1.lessonsRemaining } ?? 0
    }
    
    private var canBookLesson: Bool {
        guard let clientId = selectedClientId,
              let packageId = selectedPackageId,
              !clientId.isEmpty,
              !packageId.isEmpty,
              singleEnd > singleStart,
              !isBooking else {
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
    
    private func bookLesson() async {
        guard let clientId = selectedClientId,
              let packageId = selectedPackageId else {
            bookingError = "Please select a client and package"
            return
        }
        
        print("📝 AvailabilityEditorSheet: Starting booking...")
        print("   - clientId: \(clientId)")
        print("   - packageId: \(packageId)")
        print("   - startTime: \(singleStart)")
        print("   - endTime: \(singleEnd)")
        
        isBooking = true
        bookingError = nil
        
        // Convert dates to TimeIntervals to avoid memory corruption
        let startInterval = singleStart.timeIntervalSinceReferenceDate
        let endInterval = singleEnd.timeIntervalSinceReferenceDate
        
        // Call the synchronous closure that will trigger async work
        onBookLesson(clientId, startInterval, endInterval, packageId)
        
        // Wait a moment for booking to process
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        isBooking = false
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
        onSaveSingle(singleDay, startOnDay, endOnDay, singleStatus, applyToAllTrainers)
        dismiss()
    }

    private func applyRecurring() {
        // Send to Cloud Function with 60-minute duration and selected weekdays
        let startDateToUse = bulkStartDate ?? Calendar.current.startOfDay(for: defaultDay)
        
        // If not ongoing and no end date set, default to 1 month after start
        let endDateToUse: Date?
        if recurringOngoing {
            endDateToUse = nil
        } else if let end = bulkEndDate {
            endDateToUse = end
        } else {
            // Default to 1 month after start if user never explicitly set an end date
            endDateToUse = Calendar.current.date(byAdding: .month, value: 1, to: startDateToUse)
        }
        
        let daysArray = selectedWeekdays.isEmpty ? nil : Array(selectedWeekdays).sorted()

        onSaveOngoing(startDateToUse, endDateToUse, recurringStartHour, recurringEndHour, 60, daysArray, singleStatus, applyToAllTrainers)
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

