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

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(weekDays, id: \.self) { day in
                        DayPill(
                            date: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                selectedDate = day
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct DayPill: View {
    let date: Date
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(date, format: .dateTime.day())
                .font(.headline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
        )
        .contentShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
    }
}
