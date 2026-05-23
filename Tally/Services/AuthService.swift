//
//  AuthService.swift
//  Tally
//
//  Manages authentication state via Supabase Auth.
//  Supports Apple Sign-In and email/password.

import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

@Observable
final class AuthService {
    var session: Session?
    var isLoading = true

    var isSignedIn: Bool { session != nil }
    var userId: String? { session?.user.id.uuidString }

    private let client = SupabaseManager.client

    /// Restore session on launch and listen for auth changes
    func initialize() async {
        do {
            session = try await client.auth.session
        } catch {
            session = nil
        }
        isLoading = false

        // Listen for future auth state changes
        for await (event, session) in client.auth.authStateChanges {
            if event == .signedOut {
                self.session = nil
            } else {
                self.session = session
            }
        }
    }

    // MARK: - Email / Password

    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(displayName)]
        )
        session = result.session
    }

    func signIn(email: String, password: String) async throws {
        session = try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    // MARK: - Apple Sign-In

    /// Generate a nonce for Apple Sign-In
    func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, nonce: String) async throws {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8)
        else {
            throw AuthError.missingAppleCredential
        }

        session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: identityToken,
                nonce: nonce
            )
        )
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case missingAppleCredential

    var errorDescription: String? {
        switch self {
        case .missingAppleCredential:
            return "Could not retrieve Apple Sign-In credentials."
        }
    }
}
