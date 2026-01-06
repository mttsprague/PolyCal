// AuthManager.swift
import Foundation
import SwiftUI
import Combine

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
    @Published var isAdmin: Bool = false

    // Trainer profile fields (from /trainers/{uid})
    @Published var trainerDisplayName: String?
    @Published var trainerPhotoURLString: String?

    // Fields for convenience in the MoreView
    @Published var emailInput: String = ""
    @Published var passwordInput: String = ""
    @Published var firstNameInput: String = ""
    @Published var lastNameInput: String = ""

    #if canImport(FirebaseAuth)
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    #endif

    init() {
        #if canImport(FirebaseAuth)
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.isAuthenticated = (user != nil)
            self.userId = user?.uid
            self.userEmail = user?.email
            Task {
                await self.refreshTrainerStatus()
                await self.refreshTrainerProfileIfNeeded()
            }
        }
        #else
        // No FirebaseAuth in this build
        self.isAuthenticated = false
        self.userId = nil
        self.userEmail = nil
        self.isTrainer = false
        #endif
    }

    deinit {
        #if canImport(FirebaseAuth)
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
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
            await refreshTrainerProfileIfNeeded()
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
            await refreshTrainerProfileIfNeeded()
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
            self.isAdmin = false
            self.userId = nil
            self.userEmail = nil
            self.trainerDisplayName = nil
            self.trainerPhotoURLString = nil
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

    // MARK: - Status/profile helpers

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

    func refreshTrainerProfileIfNeeded() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard isTrainer, let uid = Auth.auth().currentUser?.uid else {
            self.trainerDisplayName = nil
            self.trainerPhotoURLString = nil
            self.isAdmin = false
            return
        }
        do {
            let ref = Firestore.firestore().collection("trainers").document(uid)
            let snap = try await ref.getDocument()
            if let data = snap.data() {
                self.trainerDisplayName = (data["name"] as? String) ?? self.trainerDisplayName
                // Check both "isAdmin" and "admin" for backwards compatibility
                self.isAdmin = (data["isAdmin"] as? Bool) ?? (data["admin"] as? Bool) ?? false
                
                // Debug logging
                print("🔐 AuthManager: Loaded trainer profile for \(uid)")
                print("   - isAdmin: \(self.isAdmin)")
                print("   - isAdmin field in Firestore: \(data["isAdmin"] ?? "nil")")
                print("   - admin field in Firestore: \(data["admin"] ?? "nil")")
                
                if let url = data["photoURL"] as? String, !url.isEmpty {
                    self.trainerPhotoURLString = url
                } else if let url = data["avatarUrl"] as? String, !url.isEmpty {
                    self.trainerPhotoURLString = url
                }
            }
        } catch {
            print("⚠️ AuthManager: Error loading trainer profile: \(error.localizedDescription)")
            // Leave previous values; optionally surface error
        }
        #endif
    }
}
