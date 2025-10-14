// ClientDetailView.swift
import SwiftUI

struct ClientDetailView: View {
    let client: Client

    var body: some View {
        List {
            Section("Contact") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(client.fullName).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Email")
                    Spacer()
                    Text(client.emailAddress).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(client.phoneNumber).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(client.firstName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
