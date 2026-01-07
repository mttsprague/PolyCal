//
//  WeekStrip.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct WeekStrip: View {
    let title: String
    let weekDays: [Date]
    @Binding var selectedDate: Date

    // Optional week navigation actions
    var onPrevWeek: (() -> Void)? = nil
    var onNextWeek: (() -> Void)? = nil
    
    // Layout constants to match ScheduleView
    private let timeColWidth: CGFloat = 56

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    onPrevWeek?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .padding(8)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(title)
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    onNextWeek?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Evenly spaced 7-day row aligned with schedule grid
            GeometryReader { geometry in
                let horizontalPaddingPerCell: CGFloat = 6
                let totalHorizontalPadding = horizontalPaddingPerCell * 2 * 7 // 6px on each side of 7 cells
                let availableWidth = geometry.size.width - timeColWidth - totalHorizontalPadding
                let calculatedDayWidth = availableWidth / 7
                
                HStack(spacing: 0) {
                    // Time column spacer to align with schedule
                    Color.clear
                        .frame(width: timeColWidth)
                    
                    HStack(spacing: 0) {
                        ForEach(weekDays, id: \.self) { day in
                            DayPill(
                                date: day,
                                isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate)
                            )
                            .frame(width: calculatedDayWidth)
                            .padding(.horizontal, horizontalPaddingPerCell)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    selectedDate = day
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 60)
        }
    }
}

private struct DayPill: View {
    let date: Date
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Weekday outside of the bubble (abbreviated)
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            // Small circle with day number
            Text(date, format: .dateTime.day())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                )
                .overlay(
                    Circle().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25))
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
    }
}
