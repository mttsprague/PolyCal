//
//  ProfileView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ProfileView: View {
    let profile: Profile

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                        )
                    VStack(alignment: .leading) {
                        Text(profile.displayName ?? "Unknown")
                            .font(.headline)
                        Text(profile.email ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Profile")
    }
}
