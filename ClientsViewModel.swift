// ClientsViewModel.swift
import Foundation

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: FirestoreService
    private let trainerId: String

    init(service: FirestoreService = .shared, trainerId: String = "trainer_demo") {
        self.service = service
        self.trainerId = trainerId
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.fetchTrainerClients(trainerId: trainerId)
            self.clients = result.sorted { $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending }
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
