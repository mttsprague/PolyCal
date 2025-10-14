//
//  DayScheduleView.swift
//  PolyCal
//
//  Created by Assistant on 10/14/25.
//

import SwiftUI

struct DayScheduleView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject var viewModel: ScheduleViewModel

    // Layout constants for list presentation
    private let rowCornerRadius: CGFloat = 12

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Same header (avatar + name) as ScheduleView
                header

                // Same week strip, defaulting to today's date; blue highlight = selected day
                WeekStrip(
                    title: viewModel.weekTitle,
                    weekDays: viewModel.weekDays,
                    selectedDate: $viewModel.selectedDate,
                    onPrevWeek: { shiftWeek(by: -1) },
                    onNextWeek: { shiftWeek(by: 1) }
                )
                .padding(.top, 2)
                .padding(.bottom, 8)

                // Day content
                ScrollView {
                    VStack(spacing: 12) {
                        let key = DateOnly(viewModel.selectedDate)
                        let slots = (viewModel.slotsByDay[key] ?? []).sorted { $0.startTime < $1.startTime }

                        if slots.isEmpty {
                            emptyState
                                .padding(.top, 24)
                        } else {
                            ForEach(slots) { slot in
                                DayEventRow(slot: slot)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Day")
                        .font(.headline)
                }
            }
            .task {
                // Ensure we have data for the current week when this view appears
                await viewModel.loadWeek()
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                Task { await viewModel.loadWeek() }
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

    // MARK: - Header (same as ScheduleView)
    private var header: some View {
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No items for this day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct DayEventRow: View {
    let slot: TrainerScheduleSlot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time badge
            VStack(spacing: 4) {
                Text(timeRange(slot))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 84)

            // Content card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(slot.visualColor)
                        .frame(width: 8, height: 8)
                    Text(slot.displayTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                if slot.isBooked, let name = slot.clientName {
                    Text(name)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(statusText(slot))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(slot.visualColor.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(slot.visualColor.opacity(0.25))
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slot.displayTitle), \(timeRange(slot))")
    }

    private func timeRange(_ slot: TrainerScheduleSlot) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return "\(fmt.string(from: slot.startTime)) – \(fmt.string(from: slot.endTime))"
    }

    private func statusText(_ slot: TrainerScheduleSlot) -> String {
        if slot.isBooked { return "Booked" }
        switch slot.status {
        case .open: return "Open"
        case .unavailable: return "Unavailable"
        }
    }
}

#Preview {
    DayScheduleView(viewModel: ScheduleViewModel())
        .environmentObject(AuthManager())
}
