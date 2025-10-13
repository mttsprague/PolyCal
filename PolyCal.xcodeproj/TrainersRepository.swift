//
//  TrainersRepository.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

struct TrainersRepository {
    func fetchAllTrainers() async throws -> [Trainer] {
        try await FirestoreService.shared.fetchAllTrainers()
    }
}
