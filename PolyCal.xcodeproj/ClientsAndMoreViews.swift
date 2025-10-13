//
//  ClientsAndMoreViews.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

// Existing ClientsView and ClientRow remain here if you previously added them.

struct MoreView: View {
    @StateObject private var session = AuthSession.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBadge

                    Text("More")
                        .font(.system(size: 44, weight: .heavy))
                        .padding(.top, 4)

                    if session.isSignedIn {
                        NavigationLink {
                            ProfileView(profile: Profile(displayName: session.displayName, email: session.email, photoURL: session.photoURL))
                        } label: {
                            profileRow(displayName: session.displayName ?? "Account", email: session.email ?? "")
                                .padding(.horizontal)
                        }
                    } else {
                        signInButton
                            .padding(.horizontal)
                    }

                    VStack(spacing: 16) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("More")
                            .font(.title2.weight(.semibold))
                        Text("Settings and other options will appear here.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
        }
    }

    private var headerBadge: some View {
        HStack {
            Label(session.displayName ?? "Guest", systemImage: "person.circle")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
        }
        .padding(.top, 8)
    }

    private func profileRow(displayName: String, email: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName).font(.headline)
                Text(email).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }

    private var signInButton: some View {
        Button {
            Task { try? await session.signInAnonymously() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                Text("Sign up / Sign in")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}
