//
//  ScheduleView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI
import FirebaseFirestore

struct ScheduleView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var viewModel = ScheduleViewModel()

    // Editor presentation state driven by an Identifiable item
    private struct EditorContext: Identifiable, Equatable {
        let id = UUID()
        let day: Date
        let hour: Int
    }
    @State private var editorContext: EditorContext?
    
    // Class sheet presentation with identifiable item
    private struct ClassSheetContext: Identifiable {
        let id = UUID()
        let classId: String
        let className: String
        let participants: [ClassParticipant]?
    }
    @State private var classSheetContext: ClassSheetContext?

    // Options menu
    @State private var showOptions = false

    // Navigation to other schedule modes
    @State private var navigateToMyDay = false
    @State private var navigateToAllTrainersDay = false

    // Client card sheet context
    private struct ClientCardContext: Identifiable {
        let id = UUID()
        let client: Client
        let booking: ClientBooking?
    }
    @State private var clientCardContext: ClientCardContext?


    // Layout constants
    private let rowHeight: CGFloat = 32
    private let rowVerticalPadding: CGFloat = 6
    private let timeColWidth: CGFloat = 56
    private let dayColumnWidth: CGFloat = 47
    private let columnSpacing: CGFloat = 0
    
    // Track if we've done initial scroll to current time
    @State private var hasScrolledToCurrentTime = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                
                // Admin trainer selector
                if auth.isAdmin {
                    trainerSelectorView
                }

                WeekStrip(
                    title: viewModel.weekTitle,
                    weekDays: viewModel.weekDays,
                    selectedDate: $viewModel.selectedDate,
                    onPrevWeek: { shiftWeek(by: -1) },
                    onNextWeek: { shiftWeek(by: 1) }
                )
                .padding(.top, 2)
                .padding(.bottom, 4)

                GeometryReader { geometry in
                    let horizontalPaddingPerCell: CGFloat = 6
                    let totalHorizontalPadding = horizontalPaddingPerCell * 2 * 7 // 6px on each side of 7 cells
                    let availableWidth = geometry.size.width - timeColWidth - totalHorizontalPadding
                    let calculatedDayWidth = availableWidth / 7
                    
                    ZStack(alignment: .topLeading) {
                        ScrollViewReader { verticalScrollProxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                HStack(spacing: 0) {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.visibleHours, id: \.self) { hour in
                                            Text(hourLabel(hour))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .padding(.trailing, 6)
                                                .frame(height: rowHeight)
                                                .background(Color(UIColor.systemGray6))
                                                .padding(.vertical, rowVerticalPadding)
                                                .id("hour-\(hour)")
                                        }
                                    }
                                    .frame(width: timeColWidth)
                                    .background(Color(UIColor.systemGray6))

                                    HStack(spacing: columnSpacing) {
                                        ForEach(viewModel.weekDays, id: \.self) { day in
                                            VStack(spacing: 0) {
                                                ForEach(viewModel.visibleHours, id: \.self) { hour in
                                                    HourDayCell(
                                                        day: day,
                                                        hour: hour,
                                                        slotsForDay: viewModel.slotsByDay[DateOnly(day)] ?? [],
                                                        dayColumnWidth: calculatedDayWidth,
                                                        rowHeight: rowHeight,
                                                        horizontalPadding: 6,
                                                        onEmptyTap: {
                                                            editorContext = EditorContext(day: day, hour: hour)
                                                        },
                                                        onSlotTap: { slot in
                                                            handleSlotTap(slot, defaultDay: day, defaultHour: hour)
                                                        },
                                                        onSetStatus: { status in
                                                            Task { await viewModel.setSlotStatus(on: day, hour: hour, status: status) }
                                                        },
                                                        onClear: {
                                                            Task { await viewModel.clearSlot(on: day, hour: hour) }
                                                        }
                                                    )
                                                    .padding(.vertical, rowVerticalPadding)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                            .background(Color(UIColor.systemGray6))
                            .onAppear {
                                scrollToCurrentTime(verticalScrollProxy: verticalScrollProxy)
                            }
                        }

                        TimelineView(.everyMinute) { context in
                            if let y = currentTimeYOffset(for: context.date,
                                                          firstHour: viewModel.visibleHours.first,
                                                          rowHeight: rowHeight,
                                                          rowVerticalPadding: rowVerticalPadding) {
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(height: 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .offset(x: 0, y: y)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                viewModel.setTrainerId(auth.userId ?? "trainer_demo")
                await viewModel.loadWeek()
                
                // Load all trainers if admin
                if auth.isAdmin {
                    await viewModel.loadAllTrainers()
                }
            }
            .onChange(of: auth.userId) { _, newValue in
                viewModel.setTrainerId(newValue ?? "trainer_demo")
            }
            .onChange(of: auth.isTrainer) { _, _ in
                Task {
                    await auth.refreshTrainerProfileIfNeeded()
                    await viewModel.loadWeek()
                }
            }
            .onChange(of: auth.isAdmin) { _, isAdmin in
                if isAdmin {
                    Task {
                        await viewModel.loadAllTrainers()
                    }
                }
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                Task { await viewModel.loadWeek() }
            }
            .sheet(item: $editorContext, onDismiss: {
                editorContext = nil
            }) { ctx in
                AvailabilityEditorSheet(
                    defaultDay: ctx.day,
                    defaultHour: ctx.hour,
                    isAdmin: auth.isAdmin,
                    editingTrainerId: viewModel.editingTrainerId,
                    onSaveSingle: { day, start, end, status in
                        Task {
                            await viewModel.setCustomSlot(on: day, startTime: start, endTime: end, status: status)
                            editorContext = nil
                        }
                    },
                    onSaveOngoing: { startDate, endDate, dailyStartHour, dailyEndHour, durationMinutes, daysOfWeek in
                        Task {
                            await viewModel.openAvailability(
                                start: startDate,
                                end: endDate,
                                dailyStartHour: dailyStartHour,
                                dailyEndHour: dailyEndHour,
                                slotDurationMinutes: durationMinutes,
                                selectedDaysOfWeek: daysOfWeek
                            )
                            editorContext = nil
                        }
                    },
                    onBookLesson: { clientId, startInterval, endInterval, packageId in
                        print("📋 ScheduleView: Received booking request")
                        // Store parameters and trigger async booking in a Task
                        Task {
                            let startTime = Date(timeIntervalSinceReferenceDate: startInterval)
                            let endTime = Date(timeIntervalSinceReferenceDate: endInterval)
                            let _ = await viewModel.bookLessonForClient(
                                clientId: clientId,
                                startTime: startTime,
                                endTime: endTime,
                                packageId: packageId
                            )
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showOptions) {
                ScheduleOptionsView(
                    onMyWeek: {
                        viewModel.setMode(.myWeek)
                    },
                    onMyDay: {
                        viewModel.setMode(.myDay)
                        navigateToMyDay = true
                    },
                    onAllTrainersDay: {
                        viewModel.setMode(.allTrainersDay)
                        navigateToAllTrainersDay = true
                    },
                    onSelectTrainer: { id in
                        viewModel.setMode(.trainerDay(id))
                    }
                )
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(isPresented: $navigateToMyDay) {
                DayScheduleView(viewModel: viewModel)
                    .environmentObject(auth)
            }
            .navigationDestination(isPresented: $navigateToAllTrainersDay) {
                AllTrainersDayView(scheduleViewModel: viewModel)
                    .environmentObject(auth)
            }
            .sheet(item: $clientCardContext) { context in
                ClientCardView(client: context.client, selectedBooking: context.booking)
            }
            .sheet(item: $classSheetContext) { context in
                ClassParticipantsView(
                    classId: context.classId,
                    classTitle: context.className,
                    preloadedParticipants: context.participants
                )
            }
        }
    }

    private func shiftWeek(by delta: Int) {
        let cal = Calendar.current
        if let newDate = cal.date(byAdding: .day, value: 7 * delta, to: viewModel.selectedDate) {
            withAnimation(.easeInOut) {
                viewModel.selectedDate = newDate
            }
        }
    }
    
    private func scrollToCurrentDay(scrollProxy: ScrollViewProxy) {
        // Find the exact Date instance from weekDays that matches selectedDate (same calendar day)
        let cal = Calendar.current
        let target = viewModel.weekDays.first(where: { cal.isDate($0, inSameDayAs: viewModel.selectedDate) }) ?? viewModel.selectedDate
        scrollProxy.scrollTo(target, anchor: .center)
    }
    
    private func scrollToCurrentTime(verticalScrollProxy: ScrollViewProxy) {
        guard !hasScrolledToCurrentTime else { return }
        
        let now = Date()
        let comps = Calendar.current.dateComponents([.hour], from: now)
        guard let currentHour = comps.hour else { return }
        
        // Scroll to the current hour, centered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.5)) {
                verticalScrollProxy.scrollTo("hour-\(currentHour)", anchor: .center)
            }
            hasScrolledToCurrentTime = true
        }
    }

    private func refreshSchedule() async {
        print("🔄 Refreshing schedule...")
        await viewModel.loadWeek()
        print("✅ Schedule refreshed")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                showOptions = true
            } label: {
                HStack(spacing: 12) {
                    avatarView
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.trainerDisplayName ?? "My Schedule")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if auth.isAuthenticated {
                            Text(auth.isAdmin ? "Admin" : "You")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Refresh button
            Button {
                Task {
                    await refreshSchedule()
                }
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .padding(.top, 8)
    }
    
    private var trainerSelectorView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Editing Schedule For:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Picker("Trainer", selection: Binding(
                get: { viewModel.editingTrainerId ?? auth.userId ?? "" },
                set: { newValue in
                    viewModel.editingTrainerId = newValue
                    Task { await viewModel.loadWeek() }
                }
            )) {
                ForEach(viewModel.allTrainers) { trainer in
                    Text(trainer.displayName).tag(trainer.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlString = auth.trainerPhotoURLString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle().fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                case .failure:
                    Circle().fill(Color.gray.opacity(0.2))
                        .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 20)).foregroundStyle(.secondary))
                @unknown default:
                    Circle().fill(Color.gray.opacity(0.2))
                }
            }
        } else {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                )
        }
    }

    // Helpers

    private func hourLabel(_ hour: Int) -> String {
        let comps = DateComponents(calendar: Calendar.current, hour: hour)
        let date = comps.date ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func dateBySetting(hour: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func currentTimeYOffset(for date: Date, firstHour: Int?, rowHeight: CGFloat, rowVerticalPadding: CGFloat) -> CGFloat? {
        guard let firstHour, let lastHour = viewModel.visibleHours.last else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return nil }
        if hour < firstHour || hour > lastHour + 1 { return nil }

        let perHourHeight = rowHeight + (rowVerticalPadding * 2)
        let initialTopPadding: CGFloat = rowVerticalPadding
        let wholeHours = CGFloat(max(0, hour - firstHour))
        let fraction = CGFloat(min(max(minute, 0), 59)) / 60.0
        return initialTopPadding + (wholeHours + fraction) * perHourHeight
    }

    private func handleSlotTap(_ slot: TrainerScheduleSlot, defaultDay: Date, defaultHour: Int) {
        // Check if this is a class booking
        if slot.isClass, let classId = slot.classId {
            // Use cached participants if available
            if let cached = viewModel.participantsByClassId[classId] {
                // Present sheet with context item
                self.classSheetContext = ClassSheetContext(
                    classId: classId,
                    className: slot.clientName ?? "Group Class",
                    participants: cached
                )
                return
            }
            
            // Fallback: Pre-load participants if not in cache (shouldn't happen normally)
            Task {
                do {
                    let participants = try await fetchParticipants(classId: classId)
                    await MainActor.run {
                        viewModel.participantsByClassId[classId] = participants
                        self.classSheetContext = ClassSheetContext(
                            classId: classId,
                            className: slot.clientName ?? "Group Class",
                            participants: participants
                        )
                    }
                } catch {
                    print("Error loading participants: \(error)")
                    await MainActor.run {
                        // Show sheet anyway with empty participants list
                        self.classSheetContext = ClassSheetContext(
                            classId: classId,
                            className: slot.clientName ?? "Group Class",
                            participants: []
                        )
                    }
                }
            }
            return
        }
        
        // Handle regular client booking
        if slot.isBooked, let clientId = slot.clientId {
            // Check cache first
            if let cached = viewModel.clientsById[clientId] {
                let booking = ClientBooking(
                    id: slot.id,
                    trainerId: slot.trainerId,
                    trainerName: auth.trainerDisplayName ?? "Trainer",
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                    status: "confirmed",
                    bookedAt: slot.bookedAt,
                    isClassBooking: slot.isClassBooking,
                    classId: slot.classId
                )
                self.clientCardContext = ClientCardContext(client: cached, booking: booking)
                return
            }

            // Fetch data BEFORE showing sheet
            Task {
                let fetched = try? await FirestoreService.shared.fetchClient(by: clientId)
                await MainActor.run {
                    let client = fetched ?? Client(
                        id: clientId,
                        firstName: slot.clientName ?? "Booked",
                        lastName: "",
                        emailAddress: "",
                        phoneNumber: "",
                        photoURL: nil
                    )
                    
                    if let fetched = fetched {
                        viewModel.clientsById[clientId] = fetched
                    }
                    
                    let booking = ClientBooking(
                        id: slot.id,
                        trainerId: slot.trainerId,
                        trainerName: auth.trainerDisplayName ?? "Trainer",
                        startTime: slot.startTime,
                        endTime: slot.endTime,
                        status: "confirmed",
                        bookedAt: slot.bookedAt,
                        isClassBooking: slot.isClassBooking,
                        classId: slot.classId
                    )
                    
                    self.clientCardContext = ClientCardContext(client: client, booking: booking)
                }
            }
        } else {
            // Drive the sheet with an Identifiable item so init sees the correct values
            editorContext = EditorContext(day: defaultDay, hour: defaultHour)
        }
    }
    
    private func fetchParticipants(classId: String) async throws -> [ClassParticipant] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("classes")
            .document(classId)
            .collection("participants")
            .order(by: "registeredAt", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let firstName = data["firstName"] as? String,
                  let lastName = data["lastName"] as? String,
                  let registeredAtTimestamp = data["registeredAt"] as? Timestamp else {
                return nil
            }
            
            return ClassParticipant(
                id: doc.documentID,
                userId: userId,
                firstName: firstName,
                lastName: lastName,
                registeredAt: registeredAtTimestamp.dateValue()
            )
        }
    }

    // MARK: - Helper Views (nested)

    private struct HourDayCell: View {
        let day: Date
        let hour: Int
        let slotsForDay: [TrainerScheduleSlot]
        let dayColumnWidth: CGFloat
        let rowHeight: CGFloat
        let horizontalPadding: CGFloat
        let onEmptyTap: () -> Void
        let onSlotTap: (TrainerScheduleSlot) -> Void
        let onSetStatus: (TrainerScheduleSlot.Status) -> Void
        let onClear: () -> Void

        // Computed values to avoid local lets in body builder
        private var cellStart: Date {
            Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        private var cellEnd: Date {
            Calendar.current.date(byAdding: .hour, value: 1, to: cellStart) ?? cellStart.addingTimeInterval(3600)
        }
        private var matching: [TrainerScheduleSlot] {
            slotsForDay.filter { $0.startTime < cellEnd && $0.endTime > cellStart }
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray5))
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.systemGray3), lineWidth: 0.5)

                ForEach(matching) { slot in
                    EventCell(slot: slot)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSlotTap(slot)
                        }
                }
            }
            .frame(width: dayColumnWidth, height: rowHeight)
            .padding(.horizontal, horizontalPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                if matching.isEmpty {
                    onEmptyTap()
                }
            }
            .contextMenu {
                Button {
                    onSetStatus(.open)
                } label: {
                    Label("Set Available", systemImage: "checkmark.circle")
                }
                Button(role: .destructive) {
                    onSetStatus(.unavailable)
                } label: {
                    Label("Set Unavailable", systemImage: "xmark.circle")
                }
                Divider()
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
        }
    }

    private struct EventCell: View {
        let slot: TrainerScheduleSlot

        var body: some View {
            VStack(spacing: 2) {
                Text(slot.displayTitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(slot.visualColor)
            )
        }
    }

    private struct ClientDetailSheet: View {
        let client: Client

        var body: some View {
            VStack(spacing: 16) {
                if let urlString = client.photoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                                .transition(.opacity)
                        case .empty, .failure:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 72, height: 72)
                                .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(.secondary))
                        @unknown default:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 72, height: 72)
                                .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(.secondary))
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 72, height: 72)
                        .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(.secondary))
                }

                VStack(spacing: 4) {
                    Text(client.fullName)
                        .font(.title3.weight(.semibold))
                    if !client.emailAddress.isEmpty {
                        Link(destination: URL(string: "mailto:\(client.emailAddress)")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 12))
                                Text(client.emailAddress)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(AppTheme.primary)
                        }
                    }
                    if !client.phoneNumber.isEmpty {
                        VStack(spacing: Spacing.xs) {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 12))
                                Text(client.phoneNumber)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                            
                            InlinePhoneActions(phoneNumber: client.phoneNumber)
                        }
                        .padding(.top, Spacing.xxs)
                    }
                }

                Spacer()
            }
            .padding()
            .presentationDragIndicator(.visible)
        }
    }
}
