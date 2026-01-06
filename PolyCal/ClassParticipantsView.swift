//
//  ClassParticipantsView.swift
//  PolyCal
//
//  Created by Assistant on 12/31/25.
//

import SwiftUI
import FirebaseFirestore
import Combine

struct ClassParticipantsView: View {
    let classId: String
    let classTitle: String
    let preloadedParticipants: [ClassParticipant]?
    
    @StateObject private var participantsLoader: ParticipantsLoader
    @Environment(\.dismiss) private var dismiss
    @State private var selectedParticipant: ClassParticipant?
    
    init(classId: String, classTitle: String, preloadedParticipants: [ClassParticipant]? = nil) {
        self.classId = classId
        self.classTitle = classTitle
        self.preloadedParticipants = preloadedParticipants
        _participantsLoader = StateObject(wrappedValue: ParticipantsLoader(classId: classId, preloadedParticipants: preloadedParticipants))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if participantsLoader.isLoading {
                    ProgressView("Loading participants...")
                        .tint(AppTheme.primary)
                } else if participantsLoader.participants.isEmpty {
                    EmptyStateView(
                        icon: "person.3",
                        title: "No Registrations Yet",
                        message: "No one has signed up for this class yet."
                    )
                } else {
                    List {
                        Section {
                            Text("\(participantsLoader.participants.count) registered")
                                .font(.labelMedium)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Section("Participants") {
                            ForEach(participantsLoader.participants) { participant in
                                ParticipantRow(participant: participant)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedParticipant = participant
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle(classTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedParticipant) { participant in
                ParticipantClientCardSheet(participantUserId: participant.userId)
            }
        }
        .navigationViewStyle(.stack)
    }
}

// Helper view to fetch client and show card
private struct ParticipantClientCardSheet: View {
    let participantUserId: String
    @State private var client: Client?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .tint(AppTheme.primary)
            } else if let client = client {
                ClientCardView(client: client, selectedBooking: nil)
            } else {
                Text("Unable to load client information")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .task {
            do {
                client = try await FirestoreService.shared.fetchClient(by: participantUserId)
            } catch {
                print("Error fetching client: \(error)")
            }
            isLoading = false
        }
    }
}

struct ParticipantRow: View {
    let participant: ClassParticipant
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Text(participant.initials)
                    .font(.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(participant.fullName)
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("Registered \(participant.registeredAt.formatted(.relative(presentation: .named)))")
                    .font(.labelSmall)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Models

struct ClassParticipant: Identifiable, Codable {
    let id: String
    let userId: String
    let firstName: String
    let lastName: String
    let registeredAt: Date
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let first = firstName.prefix(1).uppercased()
        let last = lastName.prefix(1).uppercased()
        return "\(first)\(last)"
    }
}

// MARK: - Data Loader

@MainActor
class ParticipantsLoader: ObservableObject {
    @Published var participants: [ClassParticipant] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private let classId: String
    
    init(classId: String, preloadedParticipants: [ClassParticipant]? = nil) {
        self.classId = classId
        
        if let preloaded = preloadedParticipants {
            // Use preloaded data immediately
            self.participants = preloaded
            self.isLoading = false
        } else {
            // Load data
            Task {
                await loadParticipants()
            }
        }
    }
    
    func loadParticipants() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("classes")
                .document(classId)
                .collection("participants")
                .order(by: "registeredAt", descending: false)
                .getDocuments()
            
            participants = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let userId = data["userId"] as? String,
                      let firstName = data["firstName"] as? String,
                      let lastName = data["lastName"] as? String,
                      let timestamp = data["registeredAt"] as? Timestamp else {
                    return nil
                }
                
                return ClassParticipant(
                    id: doc.documentID,
                    userId: userId,
                    firstName: firstName,
                    lastName: lastName,
                    registeredAt: timestamp.dateValue()
                )
            }
        } catch {
            print("Error loading participants: \(error)")
            participants = []
        }
        
        isLoading = false
    }
}
