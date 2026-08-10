import SwiftUI
import Mite

struct IdentityView: View {
    @State private var anonymousId = ""
    @State private var userIdentifier: String?
    @State private var optedOut = false
    @State private var formUserId = ""
    @State private var formEmail = ""
    @State private var statusText: String?
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Current identity") {
                    LabeledContent("Anonymous id", value: anonymousId)
                    LabeledContent("User", value: userIdentifier ?? "none")
                }
                Section("Identify") {
                    TextField("User identifier", text: $formUserId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Email", text: $formEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    Button("Identify") {
                        identify()
                    }
                    .disabled(formUserId.isEmpty)
                }
                Section("Privacy") {
                    Toggle("Identification opt-out", isOn: $optedOut)
                        .onChange(of: optedOut) { value in
                            setOptOut(value)
                        }
                    Button("Log out", role: .destructive) {
                        logout()
                    }
                }
                if let statusText {
                    Section("Status") {
                        Text(statusText)
                    }
                }
            }
            .navigationTitle("Identity")
            .task { await refresh() }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorText != nil },
                    set: { if !$0 { errorText = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func refresh() async {
        guard let client = Mite.sharedIfConfigured else { return }
        anonymousId = await client.anonymousId
        userIdentifier = await client.userIdentifier
        optedOut = await client.isIdentificationOptedOut
    }

    private func identify() {
        Task {
            do {
                let response = try await Mite.shared.identify(IdentifyPayload(
                    userIdentifier: formUserId,
                    email: formEmail.isEmpty ? nil : formEmail
                ))
                statusText = "Identified (id: \(response.id), created: \(response.created))"
                await refresh()
            } catch {
                errorText = String(describing: error)
            }
        }
    }

    private func logout() {
        Task {
            await Mite.shared.logout()
            statusText = "Logged out."
            await refresh()
        }
    }

    private func setOptOut(_ value: Bool) {
        Task {
            let current = await Mite.shared.isIdentificationOptedOut
            guard current != value else { return }
            await Mite.shared.setIdentificationOptOut(value)
            statusText = value ? "Identification opted out." : "Identification allowed."
            await refresh()
        }
    }
}
