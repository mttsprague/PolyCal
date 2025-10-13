//
//  ScheduleOptionsView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ScheduleOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    let currentUserName: String?
    let onSelectMode: (ScheduleMode) -> Void
    @State private var trainers: [Trainer] = []
    @State private var isLoading = false

    private let repo = TrainersRepository()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    sectionTitle("My Schedule")
                    card {
                        VStack(spacing: 0) {
                            row(icon: "calendar", title: "My Week") { select(.myWeek) }
                            Divider()
                            row(icon: "square.split.2x1", title: "My Day") { select(.myDay) }
                        }
                    }

                    sectionTitle("Other Views")
                    card {
                        row(icon: "person.3", title: "All Trainers (Day)") { select(.allTrainersDay) }
                    }

                    sectionTitle("Trainers")
                    card {
                        VStack(spacing: 0) {
                            ForEach(trainers) { t in
                                rowAvatar(title: t.displayName) {
                                    select(.trainerDay(t.id))
                                }
                                if t.id != trainers.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Schedule Options")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .task {
                await loadTrainers()
            }
        }
    }

    private func select(_ mode: ScheduleMode) {
        onSelectMode(mode)
        dismiss()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(currentUserName ?? "You")
                    .font(.headline)
                Text("You")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func rowAvatar(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    )
                Text(title)
                    .font(.body)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func loadTrainers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            trainers = try await repo.fetchAllTrainers()
        } catch {
            trainers = []
            print("Failed to load trainers: \(error)")
        }
    }
}
