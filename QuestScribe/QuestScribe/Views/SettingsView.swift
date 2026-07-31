import SwiftUI

// MARK: - Settings

/// Simple API key management backed by the Keychain.
struct SettingsView: View {
    @Environment(PaywallManager.self) private var paywallManager

    @State private var apiKey = ""
    @State private var showSaved = false
    @State private var showPaywall = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: paywallManager.isPro ? "Pro" : "Free")
                if !paywallManager.isPro {
                    if paywallManager.localTrialActive {
                        Text("Free trial active — \(paywallManager.trialDaysRemaining) day\(paywallManager.trialDaysRemaining == 1 ? "" : "s") left.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Start Free Trial") { showPaywall = true }
                } else {
                    Button("Manage Subscription") { showPaywall = true }
                }
            } header: {
                Text("QuestScribe Pro")
            } footer: {
                Text("Pro unlocks unlimited note scanning. First 7 days are free, then $12.99/month.")
            }

            Section {
                SecureField("sk-...", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("OpenAI API Key")
            } footer: {
                Text("Stored securely in the Keychain and used only for structuring your scanned notes into quests, loot, and NPCs.")
            }

            Section {
                Button {
                    saveKey()
                } label: {
                    Text("Save Key")
                        .frame(maxWidth: .infinity)
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !apiKey.isEmpty {
                    Button("Remove Key", role: .destructive) {
                        try? KeychainHelper.deleteAPIKey()
                        apiKey = ""
                    }
                }
            }

            #if DEBUG
            Section {
                Toggle("Developer: Unlock Pro", isOn: $paywallManager.debugUnlocked)
            } footer: {
                Text("Debug builds only. Lets you test scanning without the subscription.")
            }
            #endif
        }
        .navigationTitle("Settings")
        .onAppear {
            apiKey = KeychainHelper.loadAPIKey() ?? ""
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("API Key Saved", isPresented: $showSaved) {
            Button("OK", role: .cancel) {}
        }
        .alert(
            "Couldn't Save Key",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveKey() {
        do {
            try KeychainHelper.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            showSaved = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
