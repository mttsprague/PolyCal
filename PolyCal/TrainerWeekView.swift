//
//  TrainerWeekView.swift
//  PolyCal
//
//  Created by Assistant
//

import SwiftUI
import FirebaseFirestore
import Combine

struct TrainerWeekView: View {
    @EnvironmentObject private var auth: AuthManager
    let trainerId: String
    @ObservedObject var viewModel: ScheduleViewModel
    
    @StateObject private var trainerViewModel = TrainerWeekViewModel()
    
    // Client card sheet context
    private struct ClientCardContext: Identifiable {
        let id = UUID()
        let client: Client
        let booking: ClientBooking?
    }
    @State private var clientCardContext: ClientCardContext?
    
    // Class participants sheet
    @State private var selectedClassId: String?
    @State private var selectedClassName: String?
    @State private var preloadedParticipants: [ClassParticipant]?
    @State private var classParticipantsShown: Bool = false
    
    // Layout constants (matching ScheduleView)
    private let rowHeight: CGFloat = 56
    private let rowVerticalPadding: CGFloat = 1
    private let timeColWidth: CGFloat = 56
    private let columnSpacing: CGFloat = 0
    
    // Track if we've done initial scroll to current time
    @State private var hasScrolledToCurrentTime = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with trainer info
            header
            
            // Week strip
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
                let horizontalPaddingPerCell: CGFloat = 2
                let totalHorizontalPadding = horizontalPaddingPerCell * 2 * 7
                let availableWidth = geometry.size.width - timeColWidth - totalHorizontalPadding
                let calculatedDayWidth = max(10, availableWidth / 7)
                
                ZStack(alignment: .topLeading) {
                    ScrollViewReader { verticalScrollProxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            HStack(spacing: 0) {
                                // Time column
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
                                
                                // Days grid
                                HStack(spacing: columnSpacing) {
                                    ForEach(viewModel.weekDays, id: \.self) { day in
                                        let isToday = Calendar.current.isDateInToday(day)
                                        VStack(spacing: 0) {
                                            ForEach(viewModel.visibleHours, id: \.self) { hour in
                                                HourDayCell(
                                                    day: day,
                                                    hour: hour,
                                                    slotsForDay: trainerViewModel.slotsByDay[DateOnly(day)] ?? [],
                                                    dayColumnWidth: calculatedDayWidth,
                                                    rowHeight: rowHeight,
                                                    horizontalPadding: 2,
                                                    isToday: isToday,
                                                    onEmptyTap: {},
                                                    onSlotTap: { slot in
                                                        handleSlotTap(slot, defaultDay: day, defaultHour: hour)
                                                    },
                                                    onSetStatus: { _ in },
                                                    onClear: {}
                                                )
                                                .padding(.vertical, rowVerticalPadding)
                                            }
                                        }
                                        .background(isToday ? Color.blue.opacity(0.08) : Color.clear)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .background(Color(UIColor.systemGray6))
                        .onAppear {
                            scrollToCurrentTime(verticalScrollProxy: verticalScrollProxy)
                        }
                        .onChange(of: hasScrolledToCurrentTime) { _, newValue in
                            if !newValue {
                                scrollToCurrentTime(verticalScrollProxy: verticalScrollProxy)
                            }
                        }
                    }
                    
                    // Current time indicator
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(trainerViewModel.trainer?.displayName ?? "Trainer Schedule")
                    .font(.headline)
            }
        }
        .sheet(item: $clientCardContext) { context in
            ClientCardView(client: context.client, selectedBooking: context.booking)
        }
        .sheet(isPresented: $classParticipantsShown) {
            if let classId = selectedClassId, let className = selectedClassName {
                ClassParticipantsView(
                    classId: classId,
                    classTitle: className,
                    preloadedParticipants: preloadedParticipants
                )
            }
        }
        .task {
            await trainerViewModel.loadTrainer(trainerId: trainerId)
            await trainerViewModel.loadWeek(weekDays: viewModel.weekDays, trainerId: trainerId)
        }
        .onChange(of: viewModel.selectedDate) { oldValue, newValue in
            Task {
                await trainerViewModel.loadWeek(weekDays: viewModel.weekDays, trainerId: trainerId)
            }
            // Reset scroll flag when week changes
            if !Calendar.current.isDate(oldValue, equalTo: newValue, toGranularity: .weekOfYear) {
                hasScrolledToCurrentTime = false
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            avatarView
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(trainerViewModel.trainer?.displayName ?? "Trainer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let email = trainerViewModel.trainer?.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Jump to current week button
            Button {
                jumpToCurrentWeek()
            } label: {
                Image(systemName: "calendar.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            
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
    
    private var avatarView: some View {
        Group {
            if let urlString = trainerViewModel.trainer?.photoURL,
               let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(Color.gray.opacity(0.2)).overlay(ProgressView())
                    case .success(let image):
                        image.resizable().scaledToFill().clipShape(Circle())
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
                    .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 20)).foregroundStyle(.secondary))
            }
        }
    }
    
    private func shiftWeek(by weeks: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: weeks * 7, to: viewModel.selectedDate) else { return }
        viewModel.selectedDate = newDate
    }
    
    private func jumpToCurrentWeek() {
        withAnimation(.easeInOut) {
            viewModel.selectedDate = Date()
            hasScrolledToCurrentTime = false
        }
    }
    
    private func refreshSchedule() async {
        await trainerViewModel.loadWeek(weekDays: viewModel.weekDays, trainerId: trainerId)
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
    
    private func hourLabel(_ hour: Int) -> String {
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = (hour < 12 || hour == 24) ? "am" : "pm"
        return "\(h)\(suffix)"
    }
    
    private func currentTimeYOffset(for now: Date, firstHour: Int?, rowHeight: CGFloat, rowVerticalPadding: CGFloat) -> CGFloat? {
        guard let firstHour = firstHour else { return nil }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let hoursFromStart = hour - firstHour
        guard hoursFromStart >= 0 else { return nil }
        let totalRowHeight = rowHeight + rowVerticalPadding * 2
        let fractionOfHour = CGFloat(minute) / 60.0
        return CGFloat(hoursFromStart) * totalRowHeight + fractionOfHour * totalRowHeight
    }
    
    private func handleSlotTap(_ slot: TrainerScheduleSlot, defaultDay: Date, defaultHour: Int) {
        // Check if this is a class booking
        if slot.isClass, let classId = slot.classId {
            // Use cached participants if available
            if let cached = viewModel.participantsByClassId[classId] {
                selectedClassId = classId
                selectedClassName = slot.clientName ?? "Group Class"
                preloadedParticipants = cached
                classParticipantsShown = true
                return
            }
            
            // Fetch participants BEFORE showing sheet
            Task {
                do {
                    let participants = try await fetchParticipants(classId: classId)
                    await MainActor.run {
                        viewModel.participantsByClassId[classId] = participants
                        selectedClassId = classId
                        selectedClassName = slot.clientName ?? "Group Class"
                        preloadedParticipants = participants
                        classParticipantsShown = true
                    }
                } catch {
                    print("Error loading participants: \(error)")
                    await MainActor.run {
                        selectedClassId = classId
                        selectedClassName = slot.clientName ?? "Group Class"
                        preloadedParticipants = []
                        classParticipantsShown = true
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
                    trainerName: trainerViewModel.trainer?.displayName ?? "Trainer",
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
                        trainerName: trainerViewModel.trainer?.displayName ?? "Trainer",
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
        }
    }
    
    private func fetchParticipants(classId: String) async throws -> [ClassParticipant] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("classes")
            .document(classId)
            .collection("participants")
            .order(by: "registeredAt", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { (doc) -> ClassParticipant? in
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let firstName = data["firstName"] as? String,
                  let lastName = data["lastName"] as? String,
                  let timestamp = data["registeredAt"] as? Timestamp else {
                return nil
            }
            
            return ClassParticipant(
                id: doc.documentID,
                userId: userId,
                firstName: firstName,
                lastName: lastName,
                registeredAt: timestamp.dateValue()
            )
        }
    }
}

// Local copy of HourDayCell used by TrainerWeekView
private struct HourDayCell: View {
    let day: Date
    let hour: Int
    let slotsForDay: [TrainerScheduleSlot]
    let dayColumnWidth: CGFloat
    let rowHeight: CGFloat
    let horizontalPadding: CGFloat
    let isToday: Bool
    let onEmptyTap: () -> Void
    let onSlotTap: (TrainerScheduleSlot) -> Void
    let onSetStatus: (TrainerScheduleSlot.Status) -> Void
    let onClear: () -> Void

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
                .fill(isToday ? Color(UIColor.systemGray4) : Color(UIColor.systemGray5))
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

// ViewModel for TrainerWeekView
@MainActor
final class TrainerWeekViewModel: ObservableObject {
    @Published var trainer: Trainer?
    @Published var slotsByDay: [DateOnly: [TrainerScheduleSlot]] = [:]
    
    private let scheduleRepo = ScheduleRepository()
    
    func loadTrainer(trainerId: String) async {
        do {
            trainer = try await FirestoreService.shared.fetchTrainer(by: trainerId)
        } catch {
            print("Error loading trainer: \(error)")
        }
    }
    
    func loadWeek(weekDays: [Date], trainerId: String) async {
        var newSlotsByDay: [DateOnly: [TrainerScheduleSlot]] = [:]
        let cal = Calendar.current
        
        for day in weekDays {
            do {
                let startOfDay = cal.startOfDay(for: day)
                let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(24 * 60 * 60)
                let slots = try await scheduleRepo.fetchScheduleSlots(trainerId: trainerId, from: startOfDay, to: endOfDay)
                newSlotsByDay[DateOnly(day)] = slots
            } catch {
                print("Error loading schedule for \(day): \(error)")
                newSlotsByDay[DateOnly(day)] = []
            }
        }
        
        slotsByDay = newSlotsByDay
    }
}
