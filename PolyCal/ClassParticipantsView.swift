//
//  ClassParticipantsView.swift
//  PolyCal
//
//  Created by Assistant on 12/31/25.
//

import SwiftUI
import FirebaseFirestore

struct ClassParticipantsView: View {
    let classId: String
    let classTitle: String
    
    @StateObject private var participantsLoader = ParticipantsLoader()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
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
        }
        .task {
            await participantsLoader.loadParticipants(classId: classId)
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
    
    func loadParticipants(classId: String) async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("classes")
                .document(classId)
                .collection("participants")
                .order(by: "registeredAt", descending: false)
                .getDocuments()
            
            participants = snapshot.documents.compactMap { doc in
                guard let data = doc.data() as? [String: Any],
                      let userId = data["userId"] as? String,
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
