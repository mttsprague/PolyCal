//
//  ScheduleRepository.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

struct ScheduleRepository {
    func fetchScheduleSlots(trainerId: String, from: Date, to: Date) async throws -> [TrainerScheduleSlot] {
        try await FirestoreService.shared.fetchTrainerSchedule(trainerId: trainerId, from: from, to: to)
    }

    func upsertSlot(trainerId: String, startTime: Date, endTime: Date, status: TrainerScheduleSlot.Status) async throws {
        try await FirestoreService.shared.upsertTrainerSlot(trainerId: trainerId, startTime: startTime, endTime: endTime, status: status)
    }

    func deleteSlot(trainerId: String, startTime: Date) async throws {
        try await FirestoreService.shared.deleteTrainerSlot(trainerId: trainerId, startTime: startTime)
    }
}

