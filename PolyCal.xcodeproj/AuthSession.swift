//
//  AuthSession.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI
import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class AuthSession: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var displayName: String?
    @Published var email: String?
    @Published var photoURL: URL?

    static let shared = AuthSession()

    private var handle: AnyObject?

    private init() {
        startListening()
    }

    deinit {
        stopListening()
    }

    func startListening() {
        #if canImport(FirebaseAuth)
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.isSignedIn = (user != nil)
            self.displayName = user?.displayName
            self.email = user?.email
            self.photoURL = user?.photoURL
        } as AnyObject
        #else
        isSignedIn = false
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseAuth)
        if let handle = handle as? AuthStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        #endif
    }

    func signInAnonymously() async throws {
        #if canImport(FirebaseAuth)
        _ = try await Auth.auth().signInAnonymously()
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
    }
}
