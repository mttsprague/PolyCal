//
//  ContentView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: selectedTab == 0 ? "calendar" : "calendar")
                }
                .tag(0)

            ClientsView()
                .tabItem {
                    Label("Clients", systemImage: selectedTab == 1 ? "person.2.fill" : "person.2")
                }
                .tag(1)

            MoreView()
                .tabItem {
                    Label("Account", systemImage: selectedTab == 2 ? "person.crop.circle.fill" : "person.crop.circle")
                }
                .tag(2)
        }
        .tint(AppTheme.primary)
    }
}

struct MoreView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var isSignUp: Bool = true
    @State private var isBusy: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                if auth.isAuthenticated {
                    VStack(spacing: Spacing.xl) {
                        // Profile Header
                        VStack(spacing: Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.primary, AppTheme.primaryLight],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Text(initials)
                                    .font(.displaySmall)
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(spacing: Spacing.xxs) {
                                Text(trainerName)
                                    .font(.headingLarge)
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text(auth.userEmail ?? "")
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            if auth.isTrainer {
                                BadgeView(text: "Trainer", color: AppTheme.success)
                            }
                        }
                        .padding(.top, Spacing.xl)
                        
                        // Account Info Card
                        CardView {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("Account Information")
                                    .font(.headingSmall)
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                VStack(spacing: Spacing.sm) {
                                    InfoRow(label: "Email", value: auth.userEmail ?? "Unknown")
                                    Divider()
                                    InfoRow(label: "User ID", value: auth.userId ?? "—", copyable: true)
                                    Divider()
                                    InfoRow(label: "Role", value: auth.isTrainer ? "Trainer" : "User")
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        
                        // Register as Trainer Section
                        if !auth.isTrainer {
                            CardView {
                                VStack(alignment: .leading, spacing: Spacing.md) {
                                    Text("Become a Trainer")
                                        .font(.headingSmall)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Text("Register to start accepting bookings")
                                        .font(.bodySmall)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    
                                    VStack(spacing: Spacing.sm) {
                                        TextField("First name", text: $auth.firstNameInput)
                                            .textContentType(.givenName)
                                            .autocapitalization(.words)
                                            .padding(Spacing.sm)
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(CornerRadius.xs)
                                        
                                        TextField("Last name", text: $auth.lastNameInput)
                                            .textContentType(.familyName)
                                            .autocapitalization(.words)
                                            .padding(Spacing.sm)
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(CornerRadius.xs)
                                    }
                                    
                                    Button {
                                        Task { await registerAsTrainer() }
                                    } label: {
                                        HStack(spacing: Spacing.xs) {
                                            if isBusy { ProgressView().tint(.white) }
                                            Text("Register as Trainer")
                                        }
                                    }
                                    .buttonStyle(PrimaryButtonStyle(isCompact: true))
                                    .disabled(isBusy || (auth.firstNameInput.isEmpty || auth.lastNameInput.isEmpty))
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                        
                        // Sign Out Button
                        Button {
                            auth.signOut()
                        } label: {
                            Text("Sign Out")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.horizontal, Spacing.lg)
                    }
                    .padding(.bottom, Spacing.xxxl)
                } else {
                    // Auth Screen
                    VStack(spacing: Spacing.xl) {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 60))
                                .foregroundStyle(AppTheme.primary)
                            
                            Text("Welcome to PolyCal")
                                .font(.headingLarge)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text("Sign in to manage your training schedule")
                                .font(.bodyMedium)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.xxxl)
                        
                        Picker("Mode", selection: $isSignUp) {
                            Text("Sign In").tag(false)
                            Text("Sign Up").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Spacing.lg)
                        
                        CardView {
                            VStack(spacing: Spacing.md) {
                                TextField("Email", text: $auth.emailInput)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(Spacing.sm)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(CornerRadius.xs)
                                
                                SecureField("Password", text: $auth.passwordInput)
                                    .textContentType(.password)
                                    .padding(Spacing.sm)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(CornerRadius.xs)
                                
                                if isSignUp {
                                    TextField("First name", text: $auth.firstNameInput)
                                        .textContentType(.givenName)
                                        .autocapitalization(.words)
                                        .padding(Spacing.sm)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(CornerRadius.xs)
                                    
                                    TextField("Last name", text: $auth.lastNameInput)
                                        .textContentType(.familyName)
                                        .autocapitalization(.words)
                                        .padding(Spacing.sm)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(CornerRadius.xs)
                                }
                                
                                Button {
                                    Task { await submitAuth(isSignUp: isSignUp) }
                                } label: {
                                    HStack(spacing: Spacing.xs) {
                                        if isBusy { ProgressView().tint(.white) }
                                        Text(isSignUp ? "Create Account" : "Sign In")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(isBusy || auth.emailInput.isEmpty || auth.passwordInput.isEmpty || (isSignUp && (auth.firstNameInput.isEmpty || auth.lastNameInput.isEmpty)))
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        
                        if let error = auth.errorMessage, !error.isEmpty {
                            CardView {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(AppTheme.error)
                                    Text(error)
                                        .font(.bodySmall)
                                        .foregroundStyle(AppTheme.error)
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                    }
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }
    
    private var initials: String {
        let firstName = auth.firstNameInput.isEmpty ? (auth.userEmail?.prefix(1).uppercased() ?? "U") : String(auth.firstNameInput.prefix(1))
        let lastName = auth.lastNameInput.isEmpty ? "" : String(auth.lastNameInput.prefix(1))
        return "\(firstName)\(lastName)".uppercased()
    }
    
    private var trainerName: String {
        if !auth.firstNameInput.isEmpty || !auth.lastNameInput.isEmpty {
            return "\(auth.firstNameInput) \(auth.lastNameInput)".trimmingCharacters(in: .whitespaces)
        }
        return "Trainer"
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

// Helper view for info rows
struct InfoRow: View {
    let label: String
    let value: String
    var copyable: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.bodyMedium)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            if copyable {
                Text(value)
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
