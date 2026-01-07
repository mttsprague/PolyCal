//
//  AllTrainersDayView.swift
//  PolyCal
//
//  Created by Assistant on 10/14/25.
//

import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - ViewModel for AllTrainersDay
@MainActor
final class AllTrainersDayViewModel: ObservableObject {
    @Published var trainers: [Trainer] = []
    @Published var slotsByTrainer: [String: [TrainerScheduleSlot]] = [:]
    @Published var currentDay: Date = Date()

    private let scheduleRepo = ScheduleRepository()

    func loadInitial(selectedDate: Date) async {
        do {
            let list = try await FirestoreService.shared.fetchAllTrainers()
            // Keep only active trainers
            let active = list.filter { $0.active }
            self.trainers = active
            await reload(for: selectedDate)
        } catch {
            self.trainers = []
            self.slotsByTrainer = [:]
        }
    }

    func reload(for day: Date) async {
        currentDay = day

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: day)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

        var newMap: [String: [TrainerScheduleSlot]] = [:]

        for trainer in trainers {
            do {
                let slots = try await scheduleRepo.fetchScheduleSlots(trainerId: trainer.id, from: startOfDay, to: endOfDay)
                newMap[trainer.id] = slots.sorted { $0.startTime < $1.startTime }
            } catch {
                newMap[trainer.id] = []
            }
        }

        self.slotsByTrainer = newMap
    }

    func slotFor(trainerId: String, atHour hour: Int) -> TrainerScheduleSlot? {
        guard let slots = slotsByTrainer[trainerId] else { return nil }
        let cal = Calendar.current
        guard
            let cellStart = cal.date(bySettingHour: hour, minute: 0, second: 0, of: currentDay),
            let cellEnd = cal.date(byAdding: .hour, value: 1, to: cellStart)
        else { return nil }

        // Return any slot that overlaps the hour cell (on-the-hour bookings will match exactly)
        return slots.first(where: { slot in
            slot.startTime < cellEnd && slot.endTime > cellStart
        })
    }
}

struct AllTrainersDayView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @StateObject private var viewModel = AllTrainersDayViewModel()
    
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
    private let gridHeaderVPad: CGFloat = 6
    private let horizontalPaddingPerCell: CGFloat = 2
    
    // Track if we've done initial scroll to current time
    @State private var hasScrolledToCurrentTime = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header avatar + name (current user)
                header

                // Week strip (selected day controls which day to load)
                WeekStrip(
                    title: scheduleViewModel.weekTitle,
                    weekDays: scheduleViewModel.weekDays,
                    selectedDate: $scheduleViewModel.selectedDate,
                    onPrevWeek: { shiftWeek(by: -1) },
                    onNextWeek: { shiftWeek(by: 1) }
                )
                .padding(.top, 2)
                .padding(.bottom, 4)

                let headerRowHeight = 56.0 // trainer avatar+name header height
                
                GeometryReader { geometry in
                    let trainerCount = CGFloat(max(1, viewModel.trainers.count))
                    let totalHorizontalPadding = horizontalPaddingPerCell * 2 * trainerCount
                    let availableWidth = geometry.size.width - timeColWidth - totalHorizontalPadding
                    let calculatedTrainerWidth = max(40, availableWidth / trainerCount)

                    ZStack(alignment: .topLeading) {
                        ScrollViewReader { verticalScrollProxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                HStack(spacing: 0) {
                                // Fixed left time column
                                VStack(spacing: 0) {
                                    Color.clear
                                        .frame(height: headerRowHeight + gridHeaderVPad * 2)

                                    ForEach(scheduleViewModel.visibleHours, id: \.self) { hour in
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

                                // Right: trainers header + grid
                                VStack(spacing: 0) {
                                    // Trainer headers
                                    HStack(spacing: columnSpacing) {
                                        ForEach(viewModel.trainers) { trainer in
                                            TrainerHeaderCell(trainer: trainer)
                                                .frame(width: calculatedTrainerWidth, height: headerRowHeight)
                                        }
                                    }
                                    .padding(.vertical, gridHeaderVPad)
                                    .padding(.leading, 6)
                                    .padding(.trailing, 8)

                                    VStack(spacing: 0) {
                                        ForEach(scheduleViewModel.visibleHours, id: \.self) { hour in
                                            HStack(spacing: columnSpacing) {
                                                ForEach(viewModel.trainers) { trainer in
                                                    ZStack(alignment: .topLeading) {
                                                        // Empty cell background
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color(UIColor.systemGray5))

                                                        if let slot = viewModel.slotFor(trainerId: trainer.id, atHour: hour) {
                                                            EventCell(slot: slot)
                                                                .contentShape(Rectangle())
                                                                .onTapGesture {
                                                                    handleSlotTap(slot)
                                                                }
                                                        }
                                                    }
                                                    .frame(width: calculatedTrainerWidth, height: rowHeight)
                                                    .padding(.horizontal, horizontalPaddingPerCell)
                                                }
                                            }
                                            .padding(.vertical, rowVerticalPadding)
                                        }
                                    }
                                    .padding(.bottom, 8)
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
                        }
                    }

                    // Current time bar positioned by vertical offset
                    TimelineView(.everyMinute) { context in
                        if let y = currentTimeYOffset(
                            for: context.date,
                            firstHour: scheduleViewModel.visibleHours.first,
                            rowHeight: rowHeight,
                            rowVerticalPadding: rowVerticalPadding
                        ) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .offset(x: 0, y: (headerRowHeight + gridHeaderVPad * 2) + y)
                                .accessibilityHidden(true)
                        }
                    }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("All Trainers · Day")
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
                await viewModel.loadInitial(
                    selectedDate: scheduleViewModel.selectedDate
                )
            }
            .onChange(of: scheduleViewModel.selectedDate) { _, newValue in
                Task { await viewModel.reload(for: newValue) }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    func handleSlotTap(_ slot: TrainerScheduleSlot) {
        // Check if this is a class booking
        if slot.isClass, let classId = slot.classId {
            // Use cached participants if available
            if let cached = scheduleViewModel.participantsByClassId[classId] {
                selectedClassId = classId
                selectedClassName = slot.clientName ?? "Group Class"
                self.preloadedParticipants = cached
                self.classParticipantsShown = true
                return
            }
            
            // Fetch participants BEFORE showing sheet
            Task {
                do {
                    let participants = try await fetchParticipants(classId: classId)
                    await MainActor.run {
                        scheduleViewModel.participantsByClassId[classId] = participants
                        selectedClassId = classId
                        selectedClassName = slot.clientName ?? "Group Class"
                        self.preloadedParticipants = participants
                        self.classParticipantsShown = true
                    }
                } catch {
                    print("Error loading participants: \(error)")
                    await MainActor.run {
                        selectedClassId = classId
                        selectedClassName = slot.clientName ?? "Group Class"
                        self.preloadedParticipants = []
                        self.classParticipantsShown = true
                    }
                }
            }
            return
        }
        
        // Handle regular client booking - show ClientCardView
        if slot.isBooked, let clientId = slot.clientId {
            // Check cache first
            if let client = scheduleViewModel.clientsById[clientId] {
                // Create booking info from slot
                let trainerName = viewModel.trainers
                    .first(where: { $0.id == slot.trainerId })?
                    .displayName ?? "Trainer"
                
                let booking = ClientBooking(
                    id: slot.id,
                    trainerId: slot.trainerId,
                    trainerName: trainerName,
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                    status: "confirmed",
                    bookedAt: slot.bookedAt,
                    isClassBooking: slot.isClassBooking,
                    classId: slot.classId
                )
                
                self.clientCardContext = ClientCardContext(client: client, booking: booking)
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
                        scheduleViewModel.clientsById[clientId] = fetched
                    }
                    
                    let trainerName = viewModel.trainers
                        .first(where: { $0.id == slot.trainerId })?
                        .displayName ?? "Trainer"
                    
                    let booking = ClientBooking(
                        id: slot.id,
                        trainerId: slot.trainerId,
                        trainerName: trainerName,
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
        
        var results: [ClassParticipant] = []
        for doc in snapshot.documents {
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let firstName = data["firstName"] as? String,
                  let lastName = data["lastName"] as? String,
                  let timestamp = data["registeredAt"] as? Timestamp else {
                continue
            }
            let participant = ClassParticipant(
                id: doc.documentID,
                userId: userId,
                firstName: firstName,
                lastName: lastName,
                registeredAt: timestamp.dateValue()
            )
            results.append(participant)
        }
        return results
    }

    private func shiftWeek(by delta: Int) {
        let cal = Calendar.current
        if let newDate = cal.date(byAdding: .day, value: 7 * delta, to: scheduleViewModel.selectedDate) {
            withAnimation(.easeInOut) {
                scheduleViewModel.selectedDate = newDate
            }
        }
    }
    
    private func jumpToCurrentWeek() {
        withAnimation(.easeInOut) {
            scheduleViewModel.selectedDate = Date()
            hasScrolledToCurrentTime = false
        }
    }
    
    private func refreshSchedule() async {
        await viewModel.reload(for: scheduleViewModel.selectedDate)
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

    private var header: some View {
        HStack(spacing: 12) {
            avatarView
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(auth.trainerDisplayName ?? "Schedule")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if auth.isAuthenticated {
                    Text("You")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        let comps = DateComponents(calendar: Calendar.current, hour: hour)
        let date = comps.date ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func currentTimeYOffset(for date: Date, firstHour: Int?, rowHeight: CGFloat, rowVerticalPadding: CGFloat) -> CGFloat? {
        guard let firstHour, let lastHour = scheduleViewModel.visibleHours.last else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return nil }
        if hour < firstHour || hour > lastHour + 1 { return nil }

        let perHourHeight = rowHeight + (rowVerticalPadding * 2)
        let initialTopPadding: CGFloat = rowVerticalPadding
        let wholeHours = CGFloat(max(0, hour - firstHour))
        let fraction = CGFloat(min(max(minute, 0), 59)) / 60.0
        return initialTopPadding + (wholeHours + fraction) * perHourHeight
    }
}

// MARK: - Trainer header cell
private struct TrainerHeaderCell: View {
    let trainer: Trainer

    var body: some View {
        HStack(spacing: 8) {
            TrainerAvatar(urlString: trainer.photoURL ?? trainer.avatarUrl ?? trainer.imageUrl)
                .frame(width: 28, height: 28)
            Text(trainer.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

private struct TrainerAvatar: View {
    let urlString: String?

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(Color.gray.opacity(0.2)).overlay(ProgressView())
                    case .success(let image):
                        image.resizable().scaledToFill().clipShape(Circle())
                    case .failure:
                        Circle().fill(Color.gray.opacity(0.2))
                            .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 16)).foregroundStyle(.secondary))
                    @unknown default:
                        Circle().fill(Color.gray.opacity(0.2))
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 16)).foregroundStyle(.secondary))
            }
        }
    }
}

// Local EventCell matching ScheduleView style
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

#Preview {
    AllTrainersDayView(scheduleViewModel: ScheduleViewModel())
        .environmentObject(AuthManager())
}
