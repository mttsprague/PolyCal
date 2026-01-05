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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(slot.displayTitle)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if slot.isBooked, let name = slot.clientName {
                                        Text(name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
