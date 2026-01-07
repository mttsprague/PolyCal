//
//  DayScheduleView.swift
//  PolyCal
//
//  Created by Assistant on 10/14/25.
//

import SwiftUI
import FirebaseFirestore

struct DayScheduleView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject var viewModel: ScheduleViewModel
    
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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with trainer info
                HStack(spacing: 12) {
                    avatarView
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.trainerDisplayName ?? "My Day")
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
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .padding(.top, 8)

                // Selected date title
                Text(viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Simple hour-by-hour list for the selected day
                List {
                    ForEach(viewModel.visibleHours, id: \.self) { hour in
                        let day = viewModel.selectedDate
                        let slotsForDay = viewModel.slotsByDay[DateOnly(day)] ?? []
                        let cellStart = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
                        let cellEnd = Calendar.current.date(byAdding: .hour, value: 1, to: cellStart) ?? cellStart.addingTimeInterval(3600)
                        let matching = slotsForDay.filter { $0.startTime < cellEnd && $0.endTime > cellStart }

                        HStack {
                            Text(hourLabel(hour))
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Divider()
                                .padding(.horizontal, 4)

                            if let slot = matching.first {
                                HStack(spacing: 8) {
                                    VStack(spacing: 2) {
                                        Text(slot.displayTitle)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(slot.visualColor)
                                    )
                                    
                                    if slot.isBooked, let name = slot.clientName {
                                        Text(name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    Spacer()
                                }
                                .onTapGesture {
                                    handleSlotTap(slot)
                                }
                            } else {
                                Text("No events")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                }
                .listStyle(.plain)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Day")
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
        }
        .navigationViewStyle(.stack)
    }
    
    private func handleSlotTap(_ slot: TrainerScheduleSlot) {
        // Check if this is a class booking
        if slot.isClass, let classId = slot.classId {
            selectedClassId = classId
            selectedClassName = slot.clientName ?? "Group Class"
            
            // Use cached participants if available
            if let cached = viewModel.participantsByClassId[classId] {
                self.preloadedParticipants = cached
                self.classParticipantsShown = true
            } else {
                // Show empty for now if not cached
                self.preloadedParticipants = []
                self.classParticipantsShown = true
            }
            return
        }
        
        // Handle regular client booking - show ClientCardView
        if slot.isBooked, let clientId = slot.clientId {
            // Check cache first
            if let client = viewModel.clientsById[clientId] {
                // Create booking info from slot
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
            } else {
                // Show placeholder if not cached
                let placeholderClient = Client(
                    id: clientId,
                    firstName: slot.clientName ?? "Booked",
                    lastName: "",
                    emailAddress: "",
                    phoneNumber: "",
                    photoURL: nil
                )
                
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
                
                self.clientCardContext = ClientCardContext(client: placeholderClient, booking: booking)
            }
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

    private func hourLabel(_ hour: Int) -> String {
        let comps = DateComponents(calendar: Calendar.current, hour: hour)
        let date = comps.date ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }
}

#Preview {
    DayScheduleView(viewModel: ScheduleViewModel())
        .environmentObject(AuthManager())
}
