//
//  ClientsViewModel.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class ClientsViewModel: ObservableObject {
    // Placeholder until Auth is added
    private let trainerId: String = "trainer_demo"

    @Published var clients: [Client] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: ClientsRepository

    init(repository: ClientsRepository = ClientsRepository()) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await repository.fetchClients(trainerId: trainerId)
            self.clients = result
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            self.clients = []
        }
    }
}
