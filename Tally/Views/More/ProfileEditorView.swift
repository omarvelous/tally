//
//  ProfileEditorView.swift
//  Tally
//
//  Profile editor: avatar, name, email, initials, account actions.

import SwiftUI
import SwiftData

struct ProfileEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [TallySettings]

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var initialsOverride: String = ""
    @State private var emailError: String?

    private var currentSettings: TallySettings? { settings.first }

    private var liveInitials: String {
        if !initialsOverride.isEmpty { return initialsOverride.prefix(2).uppercased() }
        let parts = name.split(separator: " ")
        let derived = parts.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
        return derived.isEmpty ? "T" : derived
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (email.isEmpty || isValidEmail(email))
    }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Avatar
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 20)
                            .fill(c.accent)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(verbatim: liveInitials)
                                    .font(TallyFont.heading(32, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                        Spacer()
                    }

                    // Name
                    fieldSection("NAME", c: c) {
                        TextField("Your name", text: $name)
                            .font(TallyFont.heading(18, weight: .medium))
                            .foregroundStyle(c.text)
                    }

                    // Email
                    fieldSection("EMAIL", c: c) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("email@example.com", text: $email)
                                .font(TallyFont.heading(18, weight: .medium))
                                .foregroundStyle(c.text)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: email) { _, newVal in
                                    if !newVal.isEmpty && !isValidEmail(newVal) {
                                        emailError = "Enter a valid email address"
                                    } else {
                                        emailError = nil
                                    }
                                }
                            if let error = emailError {
                                Text(error)
                                    .font(TallyFont.mono(11))
                                    .foregroundStyle(c.neg)
                            }
                        }
                    }

                    // Initials override
                    fieldSection("INITIALS (OPTIONAL)", c: c) {
                        TextField("Auto", text: $initialsOverride)
                            .font(TallyFont.heading(18, weight: .medium))
                            .foregroundStyle(c.text)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: initialsOverride) { _, newVal in
                                if newVal.count > 2 {
                                    initialsOverride = String(newVal.prefix(2))
                                }
                            }
                    }

                    // Account section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ACCOUNT")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                            .padding(.bottom, 8)

                        accountRow("Change password", c: c)
                        accountRow("Connected accounts", c: c)
                        accountRow("Export data", c: c)
                        accountRow("Delete account", c: c, danger: true)
                    }

                    // Sign out
                    Button {} label: {
                        Text("Sign out")
                            .font(TallyFont.heading(14, weight: .medium))
                            .foregroundStyle(c.neg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(c.neg.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(c.bg)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(c.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(!isValid)
                }
            }
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Helpers

    private func fieldSection(_ title: String, c: TallyColors, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
            content()
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(c.rule).frame(height: 1)
                }
        }
    }

    private func accountRow(_ label: String, c: TallyColors, danger: Bool = false) -> some View {
        Button {} label: {
            HStack {
                Text(label)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(danger ? c.neg : c.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(c.dim)
            }
            .padding(.vertical, 13)
            .overlay(alignment: .bottom) {
                Rectangle().fill(c.rule).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadSettings() {
        guard let s = currentSettings else { return }
        name = s.name
        email = s.email
        initialsOverride = s.initials
    }

    private func save() {
        let s: TallySettings
        if let existing = currentSettings {
            s = existing
        } else {
            s = TallySettings()
            modelContext.insert(s)
        }
        s.name = name.trimmingCharacters(in: .whitespaces)
        s.email = email.trimmingCharacters(in: .whitespaces)
        s.initials = initialsOverride.trimmingCharacters(in: .whitespaces)
        dismiss()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
