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

            // Evenly spaced 7-day row (no scroll)
            HStack(spacing: 0) {
                // Leading space to align with time column
                Color.clear
                    .frame(width: 56)
                
                ForEach(weekDays, id: \.self) { day in
                    DayPill(
                        date: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    )
                    .frame(maxWidth: .infinity) // evenly distribute
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
