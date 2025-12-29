//
//  ClientsView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ClientsView: View {
    @StateObject private var viewModel = ClientsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Hero Header
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Your Clients")
                            .font(.displayMedium)
                            .foregroundStyle(AppTheme.primary)
                        
                        Text("\(viewModel.clients.count) \(viewModel.clients.count == 1 ? "client" : "clients")")
                            .font(.bodyLarge)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, Spacing.md)

                    if let error = viewModel.errorMessage, !error.isEmpty {
                        CardView {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.error)
                                Text(error)
                                    .font(.bodySmall)
                                    .foregroundStyle(AppTheme.error)
                            }
                        }
                    }

                    if viewModel.clients.isEmpty, viewModel.errorMessage == nil {
                        EmptyStateView(
                            icon: "person.2.fill",
                            title: "No Clients Yet",
                            message: "Your clients will appear here once they book sessions with you."
                        )
                        .padding(.top, Spacing.xxxl)
                    } else {
                        VStack(spacing: Spacing.sm) {
                            ForEach(viewModel.clients) { client in
                                NavigationLink {
                                    ClientDetailView(client: client)
                                } label: {
                                    ClientRow(client: client)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    private var header: some View {
        HStack {
            Label("Jeff Schmitz", systemImage: "person.circle")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
        }
        .padding(.top, 8)
    }

    private var title: some View {
        Text("Clients")
            .font(.system(size: 44, weight: .heavy, design: .default))
            .padding(.top, 4)
    }
}

private struct ClientRow: View {
    let client: Client

    var body: some View {
        CardView(padding: Spacing.md) {
            HStack(spacing: Spacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primary.opacity(0.8), AppTheme.primaryLight.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Text(client.initials)
                        .font(.headingMedium)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(client.fullName)
                        .font(.headingSmall)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "envelope.fill")
                            .font(.labelSmall)
                        Text(client.emailAddress)
                            .font(.bodySmall)
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "phone.fill")
                            .font(.labelSmall)
                        Text(client.phoneNumber)
                            .font(.bodySmall)
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}

// Extension to get initials from client name
extension Client {
    var initials: String {
        let components = fullName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "CL"
    }
}

