//
//  AuthFlowView.swift
//  Tally
//
//  Sign in / Create account screen. Visual only — no real auth.

import SwiftUI

struct AuthFlowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthMode = .signIn
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword = false

    enum AuthMode: String { case signIn, createAccount }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Brand
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(c.accent)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text("T")
                                    .font(TallyFont.heading(18, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        Text("Tally")
                            .font(TallyFont.heading(22, weight: .medium))
                            .foregroundStyle(c.text)
                    }

                    // Headline
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode == .signIn ? "Welcome back." : "Start your streak.")
                            .font(TallyFont.heading(32, weight: .medium))
                            .foregroundStyle(c.text)
                        Text(mode == .signIn ? "Sign in to continue." : "Create an account to get started.")
                            .font(TallyFont.body(15))
                            .foregroundStyle(c.dim)
                    }

                    // Mode toggle
                    HStack(spacing: 0) {
                        modeTab("Sign in", mode: .signIn, c: c)
                        modeTab("Create account", mode: .createAccount, c: c)
                    }
                    .background(c.bg3)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // SSO buttons
                    Button { dismiss() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                            Text("Continue with Apple")
                        }
                        .font(TallyFont.heading(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(c.text)
                        .foregroundStyle(c.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button { dismiss() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                        }
                        .font(TallyFont.heading(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.clear)
                        .foregroundStyle(c.text)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // OR divider
                    HStack {
                        Rectangle().fill(c.rule).frame(height: 1)
                        Text("or")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Rectangle().fill(c.rule).frame(height: 1)
                    }

                    // Form
                    VStack(spacing: 16) {
                        if mode == .createAccount {
                            authField("Name", text: $name, c: c)
                        }
                        authField("Email", text: $email, c: c, keyboard: .emailAddress)
                        passwordField(c: c)

                        if mode == .createAccount {
                            passwordStrengthMeter(c: c)
                        }

                        if mode == .signIn {
                            HStack {
                                Spacer()
                                Button {} label: {
                                    Text("Forgot password?")
                                        .font(TallyFont.body(13))
                                        .foregroundStyle(c.accent)
                                }
                            }
                        }
                    }

                    // Submit
                    Button { dismiss() } label: {
                        Text(mode == .signIn ? "Sign in" : "Create account")
                            .font(TallyFont.heading(14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isFormValid ? c.accent : c.dim3)
                            .foregroundStyle(isFormValid ? .white : c.dim)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFormValid)

                    // Terms (sign-up only)
                    if mode == .createAccount {
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                            .font(TallyFont.body(11))
                            .foregroundStyle(c.dim)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(c.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(c.dim)
                }
            }
        }
    }

    // MARK: - Components

    private func modeTab(_ label: String, mode: AuthMode, c: TallyColors) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { self.mode = mode }
        } label: {
            Text(label)
                .font(TallyFont.mono(12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(self.mode == mode ? c.bg2 : Color.clear)
                .foregroundStyle(self.mode == mode ? c.text : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    private func authField(_ title: String, text: Binding<String>, c: TallyColors, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title.uppercased())
                .font(TallyFont.label())
                .tracking(1.2)
                .foregroundStyle(c.dim)
            TextField(title, text: text)
                .font(TallyFont.heading(16, weight: .medium))
                .foregroundStyle(c.text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(c.rule).frame(height: 1)
                }
        }
    }

    private func passwordField(c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PASSWORD")
                .font(TallyFont.label())
                .tracking(1.2)
                .foregroundStyle(c.dim)
            HStack {
                if showPassword {
                    TextField("Password", text: $password)
                        .font(TallyFont.heading(16, weight: .medium))
                } else {
                    SecureField("Password", text: $password)
                        .font(TallyFont.heading(16, weight: .medium))
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(c.dim)
                }
            }
            .foregroundStyle(c.text)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(c.rule).frame(height: 1)
            }
        }
    }

    private func passwordStrengthMeter(c: TallyColors) -> some View {
        let strength = passwordStrength
        return HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < strength ? strengthColor(strength, c: c) : c.dim3)
                    .frame(height: 4)
            }
        }
    }

    private var passwordStrength: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
           password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil { score += 1 }
        return score
    }

    private func strengthColor(_ strength: Int, c: TallyColors) -> Color {
        switch strength {
        case 1: return c.neg
        case 2: return c.warn
        case 3: return c.accent
        default: return c.pos
        }
    }

    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let passwordValid = !password.isEmpty
        if mode == .createAccount {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && emailValid && passwordValid
        }
        return emailValid && passwordValid
    }
}
