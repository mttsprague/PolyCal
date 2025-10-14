//
//  ContentView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }

            ClientsView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Clients")
                }

            MoreView()
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
        }
    }
}

struct MoreView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var isSignUp: Bool = true
    @State private var isBusy: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                if auth.isAuthenticated {
                    Section("Account") {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(auth.userEmail ?? "Unknown").foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(auth.userId ?? "—").foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Toggle("Trainer status", isOn: Binding(get: { auth.isTrainer }, set: { _ in }))
                            .disabled(true)
                    }

                    if !auth.isTrainer {
                        Section("Become a Trainer") {
                            TextField("First name", text: $auth.firstNameInput)
                                .textContentType(.givenName)
                                .autocapitalization(.words)
                            TextField("Last name", text: $auth.lastNameInput)
                                .textContentType(.familyName)
                                .autocapitalization(.words)

                            Button {
                                Task {
                                    await registerAsTrainer()
                                }
                            } label: {
                                HStack {
                                    if isBusy { ProgressView() }
                                    Text("Register as Trainer")
                                }
                            }
                            .disabled(isBusy || (auth.firstNameInput.isEmpty || auth.lastNameInput.isEmpty))
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            auth.signOut()
                        } label: {
                            Text("Sign Out")
                        }
                    }
                } else {
                    Section {
                        Picker("Mode", selection: $isSignUp) {
                            Text("Sign Up").tag(true)
                            Text("Sign In").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(isSignUp ? "Create Account" : "Sign In") {
                        TextField("Email", text: $auth.emailInput)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        SecureField("Password", text: $auth.passwordInput)
                            .textContentType(.password)

                        if isSignUp {
                            TextField("First name", text: $auth.firstNameInput)
                                .textContentType(.givenName)
                                .autocapitalization(.words)
                            TextField("Last name", text: $auth.lastNameInput)
                                .textContentType(.familyName)
                                .autocapitalization(.words)
                        }

                        Button {
                            Task {
                                await submitAuth(isSignUp: isSignUp)
                            }
                        } label: {
                            HStack {
                                if isBusy { ProgressView() }
                                Text(isSignUp ? "Create Account" : "Sign In")
                            }
                        }
                        .disabled(isBusy || auth.emailInput.isEmpty || auth.passwordInput.isEmpty || (isSignUp && (auth.firstNameInput.isEmpty || auth.lastNameInput.isEmpty)))
                    }
                }

                if let error = auth.errorMessage, !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("More")
        }
    }

    private func submitAuth(isSignUp: Bool) async {
        isBusy = true
        defer { isBusy = false }
        if isSignUp {
            await auth.signUp()
        } else {
            await auth.signIn()
        }
    }

    private func registerAsTrainer() async {
        isBusy = true
        defer { isBusy = false }
        guard let uid = auth.userId, let email = auth.userEmail else { return }
        do {
            try await auth.registerTrainerProfileOnServer(
                uid: uid,
                email: email,
                firstName: auth.firstNameInput,
                lastName: auth.lastNameInput
            )
            await auth.refreshTrainerStatus()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
