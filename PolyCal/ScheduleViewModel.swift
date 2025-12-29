//
//  ScheduleViewModel.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI
import Foundation
import Combine

enum ScheduleMode: Equatable {
    case myWeek
    case myDay
    case allTrainersDay
    case trainerDay(String) // trainerId
}

@MainActor
final class ScheduleViewModel: ObservableObject {
    // Default to demo; ScheduleView updates this from AuthManager when available
    private var myTrainerId: String = "trainer_demo"

    @Published var mode: ScheduleMode = .myWeek
    @Published var selectedTrainerId: String?

    // State used by ScheduleView
    @Published var weekDays: [Date] = []
    @Published var selectedDate: Date = Date() {
        didSet {
            // Rebuild the visible week whenever the selected day changes
            buildCurrentWeek(anchor: selectedDate)
        }
    }
    @Published var visibleHours: [Int] = Array(6...20) // 6am - 8pm
    @Published var slotsByDay: [DateOnly: [TrainerScheduleSlot]] = [:]

    // Client cache for instant presentation
    @Published var clientsById: [String: Client] = [:]

    private let scheduleRepo = ScheduleRepository()

    init() {
        buildCurrentWeek(anchor: Date())
    }

    // Allow the view to update the trainer id from Auth
    func setTrainerId(_ id: String) {
        myTrainerId = id
        Task { await loadWeek() }
    }

    // Title for the current week range, e.g. "Oct 13–19, 2025" or "Sep 30 – Oct 6, 2025"
    var weekTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: selectedDate)
        }

        let cal = Calendar.current
        let sameMonth = cal.component(.month, from: first) == cal.component(.month, from: last)
        let sameYear = cal.component(.year, from: first) == cal.component(.year, from: last)

        let startFormatter = DateFormatter()
        let endFormatter = DateFormatter()

        if sameYear {
            if sameMonth {
                startFormatter.setLocalizedDateFormatFromTemplate("MMM d")
                endFormatter.setLocalizedDateFormatFromTemplate("d, yyyy")
            } else {
                startFormatter.setLocalizedDateFormatFromTemplate("MMM d")
                endFormatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
            }
        } else {
            startFormatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
            endFormatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        }

        let startText = startFormatter.string(from: first)
        let endText = endFormatter.string(from: last)
        return "\(startText) – \(endText)"
    }

    func setMode(_ newMode: ScheduleMode) {
        mode = newMode
        switch newMode {
        case .myWeek:
            break
        case .myDay:
            break
        case .allTrainersDay:
            break
        case .trainerDay(let trainerId):
            selectedTrainerId = trainerId
        }
        Task { await loadWeek() }
    }

    func loadWeek() async {
        let trainerId: String
        switch mode {
        case .trainerDay(let id):
            trainerId = id
        default:
            trainerId = myTrainerId
        }

        // Determine week range based on selectedDate
        let cal = Calendar.current
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek) ?? selectedDate

        do {
            let slots = try await scheduleRepo.fetchScheduleSlots(trainerId: trainerId, from: startOfWeek, to: endOfWeek)
            var grouped: [DateOnly: [TrainerScheduleSlot]] = [:]
            for slot in slots {
                let key = DateOnly(slot.startTime)
                grouped[key, default: []].append(slot)
            }
            for key in grouped.keys {
                grouped[key]?.sort { $0.startTime < $1.startTime }
            }
            self.slotsByDay = grouped

            // Prefetch clients for all booked slots in this week
            await prefetchClientsForVisibleWeek()
        } catch {
            self.slotsByDay = [:]
        }
    }

    // MARK: - Prefetch clients for instant sheet presentation
    func prefetchClientsForVisibleWeek() async {
        // Collect unique client IDs from booked slots
        let allIds = Set(slotsByDay.values.flatMap { daySlots in
            daySlots.compactMap { $0.isBooked ? $0.clientId : nil }
        })
        // Skip any already cached
        let missing = allIds.subtracting(clientsById.keys)
        guard !missing.isEmpty else { return }

        // Fetch concurrently off the main actor
        var fetched: [String: Client] = [:]
        await withTaskGroup(of: (String, Client?).self) { group in
            for id in missing {
                group.addTask {
                    let client = try? await FirestoreService.shared.fetchClient(by: id)
                    return (id, client)
                }
            }
            for await (id, client) in group {
                if let client {
                    fetched[id] = client
                }
            }
        }

        // Merge into cache
        for (id, client) in fetched {
            clientsById[id] = client
        }
    }

    // MARK: - Editing availability (single slot at hour granularity)
    func setSlotStatus(on day: Date, hour: Int, status: TrainerScheduleSlot.Status) async {
        let cal = Calendar.current
        guard let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day),
              let end = cal.date(byAdding: .hour, value: 1, to: start) else { return }
        await setCustomSlot(on: day, startTime: start, endTime: end, status: status)
    }

    // Allows custom start/end (from the wheel editor)
    // Updated: Splits multi-hour blocks into one-hour slots
    func setCustomSlot(on day: Date, startTime: Date, endTime: Date, status: TrainerScheduleSlot.Status) async {
        guard endTime > startTime else { return }

        let calendar = Calendar.current
        var currentSlotStart = startTime
        let trainerId = myTrainerId

        while currentSlotStart < endTime {
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: currentSlotStart) else { break }

            // For strict 1-hour "open" slots, skip partial trailing hour
            if nextHour > endTime && status == .open {
                break
            }

            let actualSlotEnd = min(nextHour, endTime)
            do {
                try await scheduleRepo.upsertSlot(
                    trainerId: trainerId,
                    startTime: currentSlotStart,
                    endTime: actualSlotEnd,
                    status: status
                )
            } catch {
                print("Failed to upsert slot for \(currentSlotStart): \(error)")
            }

            currentSlotStart = nextHour
        }

        await loadWeek()
    }

    func clearSlot(on day: Date, hour: Int) async {
        let cal = Calendar.current
        guard let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { return }

        let trainerId = myTrainerId
        do {
            try await scheduleRepo.deleteSlot(trainerId: trainerId, startTime: start)
            await loadWeek()
        } catch {
            print("Failed to delete slot: \(error)")
        }
    }

    // MARK: - Bulk availability via Cloud Function
    func openAvailability(
        start: Date?,
        end: Date?,
        dailyStartHour: Int? = nil,
        dailyEndHour: Int? = nil,
        slotDurationMinutes: Int? = nil,
        selectedDaysOfWeek: [Int]? = nil
    ) async {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        // IMPORTANT: Use LOCAL timezone for date-only strings so the server interprets them as local days.
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"

        let startStr = start.map { fmt.string(from: $0) }
        let endStr = end.map { fmt.string(from: $0) }

        do {
            let result = try await FunctionsService.shared.processTrainerAvailability(
                startDate: startStr,
                endDate: endStr,
                dailyStartHour: dailyStartHour,
                dailyEndHour: dailyEndHour,
                slotDurationMinutes: slotDurationMinutes,
                daysOfWeek: selectedDaysOfWeek
            )
            print("processTrainerAvailability: \(result.message) slotsAdded=\(result.slotsAdded ?? 0)")
            await loadWeek()
        } catch {
            print("Failed to process availability: \(error)")
        }
    }

    private func buildCurrentWeek(anchor: Date) {
        let cal = Calendar.current
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)) ?? anchor
        weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
        if !weekDays.contains(where: { cal.isDate($0, inSameDayAs: selectedDate) }) {
            selectedDate = weekDays.first ?? anchor
        }
    }
}
