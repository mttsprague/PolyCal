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
                VStack(alignment: .leading, spacing: 16) {
                    header
                    title

                    if let error = viewModel.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.vertical, 4)
                    }

                    Divider()

                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.clients) { client in
                            NavigationLink {
                                ClientDetailView(client: client)
                            } label: {
                                ClientRow(client: client)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 72)
                        }

                        if viewModel.clients.isEmpty, viewModel.errorMessage == nil {
                            Text("No clients found.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .padding(.horizontal)
            }
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
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(client.fullName)
                    .font(.headline)
                Text(client.emailAddress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(client.phoneNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

