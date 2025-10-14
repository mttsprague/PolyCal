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

    // Designated initializer callable from nonisolated contexts (e.g., @StateObject in View init)
    nonisolated init(repository: ClientsRepository) {
        self.repository = repository
    }

    // Convenience initializer to construct the default repository on the main actor
    convenience init() {
        self.init(repository: ClientsRepository())
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await repository.fetchClients(trainerId: trainerId)
            self.clients = result.sorted { $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending }
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            self.clients = []
        }
    }
}
