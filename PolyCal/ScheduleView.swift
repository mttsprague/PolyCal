//
//  ScheduleView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var viewModel = ScheduleViewModel()

    // Editor presentation state
    @State private var editorShown = false
    @State private var editorDay: Date = Date()
    @State private var editorHour: Int = 9

    // Options menu
    @State private var showOptions = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header avatar + name (tappable)
                header

                // Reusable week strip
                WeekStrip(
                    title: viewModel.weekTitle,
                    weekDays: viewModel.weekDays,
                    selectedDate: $viewModel.selectedDate
                )
                .padding(.top, 8)
                .padding(.bottom, 12)

                Divider().opacity(0)

                // Time grid on a continuous light gray background
                TimeGrid(
                    weekDays: viewModel.weekDays,
                    visibleHours: viewModel.visibleHours,
                    slotsByDay: viewModel.slotsByDay,
                    onTapCell: { day, hour in
                        editorDay = day
                        editorHour = hour
                        editorShown = true
                    },
                    onSetStatus: { day, hour, status in
                        Task { await viewModel.setSlotStatus(on: day, hour: hour, status: status) }
                    },
                    onClear: { day, hour in
                        Task { await viewModel.clearSlot(on: day, hour: hour) }
                    }
                )
                .background(Color.secondary.opacity(0.06)) // continuous canvas
            }
            .navigationBarHidden(true)
            .task {
                // Initial trainer id wiring on first appearance
                viewModel.setTrainerId(auth.userId ?? "trainer_demo")
                await viewModel.loadWeek()
            }
            .onChange(of: auth.userId) { _, newValue in
                // Update trainer id when auth user changes
                viewModel.setTrainerId(newValue ?? "trainer_demo")
            }
            .onChange(of: auth.isTrainer) { _, _ in
                // Refresh profile and reload when trainer status changes (e.g., after registration)
                Task {
                    await auth.refreshTrainerProfileIfNeeded()
                    await viewModel.loadWeek()
                }
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                Task { await viewModel.loadWeek() }
            }
            .sheet(isPresented: $editorShown) {
                AvailabilityEditorSheet(
                    defaultDay: editorDay,
                    defaultHour: editorHour,
                    onSaveSingle: { day, start, end, status in
                        Task {
                            await viewModel.setCustomSlot(on: day, startTime: start, endTime: end, status: status)
                            editorShown = false
                        }
                    },
                    onSaveOngoing: { startDate, endDate, dailyStartHour, dailyEndHour, durationMinutes in
                        Task {
                            await viewModel.openAvailability(
                                start: startDate,
                                end: endDate,
                                dailyStartHour: dailyStartHour,
                                dailyEndHour: dailyEndHour,
                                slotDurationMinutes: durationMinutes
                            )
                            editorShown = false
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showOptions) {
                ScheduleOptionsView(
                    onMyWeek: { viewModel.setMode(.myWeek) },
                    onMyDay: { viewModel.setMode(.myDay) },
                    onAllTrainersDay: { viewModel.setMode(.allTrainersDay) },
                    onSelectTrainer: { id in viewModel.setMode(.trainerDay(id)) }
                )
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var header: some View {
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
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
}

private struct TimeGrid: View {
    let weekDays: [Date]
    let visibleHours: [Int]
    let slotsByDay: [DateOnly: [TrainerScheduleSlot]]
    let onTapCell: (Date, Int) -> Void
    let onSetStatus: (Date, Int, TrainerScheduleSlot.Status) -> Void
    let onClear: (Date, Int) -> Void

    var body: some View {
        GeometryReader { _ in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("")
                            .frame(width: 54)
                        ForEach(weekDays, id: \.self) { day in
                            VStack(spacing: 2) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(day, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                    VStack(spacing: 0) {
                        ForEach(visibleHours, id: \.self) { hour in
                            HStack(spacing: 0) {
                                Text(hourLabel(hour))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 54, alignment: .trailing)
                                    .padding(.trailing, 6)

                                ForEach(weekDays, id: \.self) { day in
                                    ZStack(alignment: .topLeading) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.secondary.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.secondary.opacity(0.12))

                                        let key = DateOnly(day)
                                        if let slots = slotsByDay[key] {
                                            ForEach(slots) { slot in
                                                if Calendar.current.isDate(
                                                    slot.startTime,
                                                    equalTo: dateBySetting(hour: hour, on: day),
                                                    toGranularity: .hour
                                                ) {
                                                    EventCell(slot: slot)
                                                        .padding(6)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 64)
                                    .padding(.horizontal, 6)
                                    .onTapGesture {
                                        onTapCell(day, hour)
                                    }
                                    .contextMenu {
                                        Button {
                                            onSetStatus(day, hour, .open)
                                        } label: {
                                            Label("Set Available", systemImage: "checkmark.circle")
                                        }
                                        Button(role: .destructive) {
                                            onSetStatus(day, hour, .unavailable)
                                        } label: {
                                            Label("Set Unavailable", systemImage: "xmark.circle")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            onClear(day, hour)
                                        } label: {
                                            Label("Clear", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .padding(.top, 4)
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let comps = DateComponents(calendar: Calendar.current, hour: hour)
        let date = comps.date ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func dateBySetting(hour: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}

private struct EventCell: View {
    let slot: TrainerScheduleSlot

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(slot.visualColor)
                .frame(width: 8, height: 8)
            Text(slot.displayTitle)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(slot.visualColor.opacity(0.08))
        )
    }
}
