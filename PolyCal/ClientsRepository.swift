//
//  ClientsRepository.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

struct ClientsRepository {
    func fetchClients(trainerId: String) async throws -> [Client] {
        try await FirestoreService.shared.fetchTrainerClients(trainerId: trainerId)
    }
}
