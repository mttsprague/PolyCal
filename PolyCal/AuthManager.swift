// AuthManager.swift
import Foundation
import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var userId: String?
    @Published var userEmail: String?
    @Published var errorMessage: String?
    @Published var isTrainer: Bool = false

    // Fields for convenience in the MoreView
    @Published var emailInput: String = ""
    @Published var passwordInput: String = ""
    @Published var firstNameInput: String = ""
    @Published var lastNameInput: String = ""

    init() {
        #if canImport(FirebaseAuth)
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.isAuthenticated = (user != nil)
            self.userId = user?.uid
            self.userEmail = user?.email
            Task { await self.refreshTrainerStatus() }
        }
        #else
        // No FirebaseAuth in this build
        self.isAuthenticated = false
        self.userId = nil
        self.userEmail = nil
        self.isTrainer = false
        #endif
    }

    // MARK: - Auth

    func signUp() async {
        errorMessage = nil
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: emailInput, password: passwordInput)
            let uid = result.user.uid

            // Create or update base user profile (allowed by your rules)
            try await FirestoreService.shared.createOrUpdateUserProfile(
                uid: uid,
                firstName: firstNameInput,
                lastName: lastNameInput,
                emailAddress: emailInput
            )

            // Call server to register as trainer (or simulate if Functions unavailable)
            try await registerTrainerProfileOnServer(uid: uid, email: emailInput, firstName: firstNameInput, lastName: lastNameInput)

            await refreshTrainerStatus()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        #else
        self.errorMessage = "FirebaseAuth is not available in this build."
        #endif
    }

    func signIn() async {
        errorMessage = nil
        #if canImport(FirebaseAuth)
        do {
            _ = try await Auth.auth().signIn(withEmail: emailInput, password: passwordInput)
            await refreshTrainerStatus()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        #else
        self.errorMessage = "FirebaseAuth is not available in this build."
        #endif
    }

    func signOut() {
        errorMessage = nil
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            self.isTrainer = false
            self.userId = nil
            self.userEmail = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        #else
        self.errorMessage = "FirebaseAuth is not available in this build."
        #endif
    }

    // MARK: - Trainer registration via Cloud Function (preferred) or simulated fallback

    func registerTrainerProfileOnServer(uid: String, email: String, firstName: String, lastName: String) async throws {
        #if canImport(FirebaseFunctions)
        let functions = Functions.functions()
        let payload: [String: Any] = [
            "uid": uid,
            "email": email,
            "firstName": firstName,
            "lastName": lastName
        ]
        do {
            _ = try await functions.httpsCallable("registerTrainer").call(payload)
        } catch {
            // If the callable is missing or you’re in a dev build, fall back to local simulation
            try await FirestoreService.shared.createOrUpdateTrainerProfile(
                trainerId: uid,
                name: "\(firstName) \(lastName)",
                email: email
            )
        }
        #elseif canImport(FirebaseFirestore)
        // Dev fallback: simulate what the function would do
        try await FirestoreService.shared.createOrUpdateTrainerProfile(
            trainerId: uid,
            name: "\(firstName) \(lastName)",
            email: email
        )
        #else
        throw FirestoreServiceError.notAvailable
        #endif
    }

    // MARK: - Status helpers

    func refreshTrainerStatus() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            self.isTrainer = false
            return
        }
        do {
            let ref = Firestore.firestore().collection("trainers").document(uid)
            let snap = try await ref.getDocument()
            self.isTrainer = snap.exists
        } catch {
            self.isTrainer = false
        }
        #else
        self.isTrainer = false
        #endif
    }
}
