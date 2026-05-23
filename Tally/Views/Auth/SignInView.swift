//
//  SignInView.swift
//  Tally
//
//  Sign-in screen with Apple Sign-In and email/password.

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / title
            VStack(spacing: 8) {
                Text("Tally")
                    .font(.largeTitle.bold())
                Text("Track your habits, build your streaks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Apple Sign-In
            SignInWithAppleButton(.signIn) { request in
                let nonce = auth.randomNonce()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = auth.sha256(nonce)
            } onCompletion: { result in
                guard let nonce = currentNonce else { return }
                Task {
                    do {
                        try await auth.handleAppleSignIn(result: result, nonce: nonce)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 24)

            dividerRow

            // Email form
            VStack(spacing: 12) {
                if isSignUp {
                    TextField("Name", text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || email.isEmpty || password.isEmpty)

                Button(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up") {
                    withAnimation {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var dividerRow: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 24)
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                if isSignUp {
                    try await auth.signUp(email: email, password: password, displayName: displayName)
                } else {
                    try await auth.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
