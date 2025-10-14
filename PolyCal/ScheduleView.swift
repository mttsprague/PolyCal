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

    // Navigation to other schedule modes
    @State private var navigateToMyDay = false
    @State private var navigateToAllTrainersDay = false

    // Layout constants
    private let rowHeight: CGFloat = 32               // skinny rows
    private let rowVerticalPadding: CGFloat = 6       // tighter spacing between rows
    private let timeColWidth: CGFloat = 56            // fixed left column width
    private let dayColumnWidth: CGFloat = 160         // width per day column (scrollable horizontally)
    private let columnSpacing: CGFloat = 0            // spacing between day columns
    private let gridHeaderVPad: CGFloat = 6           // compact vertical padding for day header

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header avatar + name (tappable)
                header

                // Week strip with chevrons and evenly spaced day bubbles
                WeekStrip(
                    title: viewModel.weekTitle,
                    weekDays: viewModel.weekDays,
                    selectedDate: $viewModel.selectedDate,
                    onPrevWeek: { shiftWeek(by: -1) },
                    onNextWeek: { shiftWeek(by: 1) }
                )
                .padding(.top, 2)
                .padding(.bottom, 4) // tighter

                // MARK: Grid (fixed time column + horizontally scrolling days, single vertical scroll)
                let headerRowHeight = 28.0 // height of the day header stack (approx)

                ZStack(alignment: .topLeading) {
                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(spacing: 0) {
                            // Fixed left time column (does not scroll horizontally)
                            VStack(spacing: 0) {
                                // Spacer to align under the day header height
                                Color.clear
                                    .frame(height: headerRowHeight + gridHeaderVPad * 2)

                                ForEach(viewModel.visibleHours, id: \.self) { hour in
                                    Text(hourLabel(hour))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.trailing, 6)
                                        .frame(height: rowHeight)
                                        .background(Color(UIColor.systemGray6))
                                        .padding(.vertical, rowVerticalPadding)
                                }
                            }
                            .frame(width: timeColWidth)
                            .background(Color(UIColor.systemGray6))

                            // Right side: days header + grid share the same horizontal scroll view
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Day header row (scrolls horizontally with grid)
                                    HStack(spacing: columnSpacing) {
                                        ForEach(viewModel.weekDays, id: \.self) { day in
                                            VStack(spacing: 2) {
                                                Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                Text(day, format: .dateTime.month(.abbreviated).day())
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(width: dayColumnWidth)
                                        }
                                    }
                                    .padding(.vertical, gridHeaderVPad)
                                    .padding(.leading, 6)
                                    .padding(.trailing, 8)

                                    // Grid rows (scroll horizontally with the header)
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.visibleHours, id: \.self) { hour in
                                            HStack(spacing: columnSpacing) {
                                                ForEach(viewModel.weekDays, id: \.self) { day in
                                                    ZStack(alignment: .topLeading) {
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color(UIColor.systemGray5))
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color(UIColor.systemGray3), lineWidth: 0.5)

                                                        let key = DateOnly(day)
                                                        if let slots = viewModel.slotsByDay[key] {
                                                            ForEach(slots) { slot in
                                                                if Calendar.current.isDate(
                                                                    slot.startTime,
                                                                    equalTo: dateBySetting(hour: hour, on: day),
                                                                    toGranularity: .hour
                                                                ) {
                                                                    EventCell(slot: slot)
                                                                        .padding(8)
                                                                }
                                                            }
                                                        }
                                                    }
                                                    .frame(width: dayColumnWidth, height: rowHeight)
                                                    .padding(.horizontal, 6)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        editorDay = day
                                                        editorHour = hour
                                                        editorShown = true
                                                    }
                                                    .contextMenu {
                                                        Button {
                                                            Task { await viewModel.setSlotStatus(on: day, hour: hour, status: .open) }
                                                        } label: {
                                                            Label("Set Available", systemImage: "checkmark.circle")
                                                        }
                                                        Button(role: .destructive) {
                                                            Task { await viewModel.setSlotStatus(on: day, hour: hour, status: .unavailable) }
                                                        } label: {
                                                            Label("Set Unavailable", systemImage: "xmark.circle")
                                                        }
                                                        Divider()
                                                        Button(role: .destructive) {
                                                            Task { await viewModel.clearSlot(on: day, hour: hour) }
                                                        } label: {
                                                            Label("Clear", systemImage: "trash")
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.vertical, rowVerticalPadding)
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                        .background(Color(UIColor.systemGray6))
                    }

                    // Current time bar – position by vertical offset; spans the right side content
                    TimelineView(.everyMinute) { context in
                        if let y = currentTimeYOffset(for: context.date,
                                                      firstHour: viewModel.visibleHours.first,
                                                      rowHeight: rowHeight,
                                                      rowVerticalPadding: rowVerticalPadding) {
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
            .navigationBarHidden(true)
            .task {
                viewModel.setTrainerId(auth.userId ?? "trainer_demo")
                await viewModel.loadWeek()
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

    // MARK: - Helpers

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
