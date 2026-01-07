//
//  TrainerWeekView.swift
//  PolyCal
//
//  Created by Assistant
//

import SwiftUI
import FirebaseFirestore

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
                                        VStack(spacing: 0) {
                                            ForEach(viewModel.visibleHours, id: \.self) { hour in
                                                HourDayCell(
                                                    day: day,
                                                    hour: hour,
                                                    slotsForDay: trainerViewModel.slotsByDay[DateOnly(day)] ?? [],
                                                    dayColumnWidth: calculatedDayWidth,
                                                    rowHeight: rowHeight,
                                                    horizontalPadding: 2,
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
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .background(Color(UIColor.systemGray6))
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
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task {
                await trainerViewModel.loadWeek(weekDays: viewModel.weekDays, trainerId: trainerId)
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
            selectedClassId = classId
            selectedClassName = slot.clientName ?? "Group Class"
            preloadedParticipants = viewModel.participantsByClassId[classId] ?? []
            classParticipantsShown = true
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
            
            // Fetch data
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
        
        for day in weekDays {
            do {
                let slots = try await scheduleRepo.fetchSchedule(for: trainerId, on: day)
                newSlotsByDay[DateOnly(day)] = slots
            } catch {
                print("Error loading schedule for \(day): \(error)")
                newSlotsByDay[DateOnly(day)] = []
            }
        }
        
        slotsByDay = newSlotsByDay
    }
}
