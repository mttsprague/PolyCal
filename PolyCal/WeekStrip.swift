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

