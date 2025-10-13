//
//  AccountView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct AccountView: View {
    @StateObject private var vm = AccountViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    segmentedControl

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Credentials").font(.headline).foregroundStyle(.secondary)

                            VStack(spacing: 16) {
                                TextField("Email", text: $vm.email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                SecureField("Password", text: $vm.password)
                                    .textContentType(.password)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                        }
                    }
                    .groupBoxStyle(.automatic)

                    if vm.mode == .create {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Profile").font(.headline).foregroundStyle(.secondary)

                                VStack(spacing: 16) {
                                    TextField("First Name", text: $vm.firstName)
                                        .textContentType(.givenName)
                                    TextField("Last Name", text: $vm.lastName)
                                        .textContentType(.familyName)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                            }
                        }
                        .groupBoxStyle(.automatic)
                    }

                    Button(action: submit) {
                        Text(vm.mode == .signIn ? "Sign In" : "Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!vm.canSubmit || vm.isWorking)

                    if let error = vm.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        vm.dismiss?()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
        }
        .task {
            vm.onSignedIn = {
                // Update global session
                AuthSession.shared.startListening()
            }
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 8) {
            segmentButton(title: "Sign In", active: vm.mode == .signIn) {
                vm.mode = .signIn
            }
            segmentButton(title: "Create Account", active: vm.mode == .create) {
                vm.mode = .create
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemBackground)))
    }

    private func segmentButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(active ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(active ? Color(.systemBackground) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        Task {
            await vm.submit()
        }
    }
}

#Preview {
    AccountView()
}
