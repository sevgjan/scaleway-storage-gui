import SwiftUI

struct AccountEditView: View {
    @Bindable var store: AppStore
    @State var draft: AccountEditDraft
    let onDismiss: () -> Void

    @State private var showDeleteConfirm = false

    private let endpointPresets: [(label: String, endpoint: String, region: String)] = [
        ("NL Amsterdam", "https://s3.nl-ams.scw.cloud", "nl-ams"),
        ("FR Paris", "https://s3.fr-par.scw.cloud", "fr-par"),
        ("PL Warsaw", "https://s3.pl-waw.scw.cloud", "pl-waw"),
    ]

    var body: some View {
        Form {
            Section("Account") {
                TextField("Display Name", text: $draft.displayName)
                TextField("Access Key ID", text: $draft.accessKeyId)

                if draft.isReplacingSecret {
                    SecureField("New Secret Access Key", text: $draft.newSecretKey)
                    Button("Cancel Replace") {
                        draft.isReplacingSecret = false
                        draft.newSecretKey = ""
                    }
                } else {
                    HStack {
                        SecureField("Secret", text: .constant("••••••••••••••••"))
                            .disabled(true)
                        Button("Replace Secret") {
                            draft.isReplacingSecret = true
                        }
                    }
                }
            }

            Section("Endpoint") {
                Picker("Preset", selection: Binding(
                    get: {
                        endpointPresets.firstIndex(where: { $0.endpoint == draft.endpointURL }) ?? 0
                    },
                    set: { idx in
                        draft.endpointURL = endpointPresets[idx].endpoint
                        draft.signingRegion = endpointPresets[idx].region
                    }
                )) {
                    ForEach(Array(endpointPresets.enumerated()), id: \.offset) { index, value in
                        Text(value.label).tag(index)
                    }
                }

                TextField("Endpoint URL", text: $draft.endpointURL)
                TextField("Signing Region", text: $draft.signingRegion)
            }

            Section {
                Button("Test Connection and Save") {
                    Task { @MainActor in
                        let ok = await store.updateAccount(draft)
                        if ok { onDismiss() }
                    }
                }
                .disabled(!canSubmit || store.isBusy)

                HStack {
                    Button("Cancel") {
                        onDismiss()
                    }
                    Spacer()
                    Button("Delete Account", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(store.isBusy)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 420)
        .padding()
        .confirmationDialog(
            "Delete \"\(draft.displayName)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { @MainActor in
                    if let profile = store.accounts.first(where: { $0.id == draft.id }) {
                        await store.deleteAccount(profile)
                    }
                    onDismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the profile and its Keychain entry. This cannot be undone.")
        }
    }

    private var canSubmit: Bool {
        !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: draft.endpointURL) != nil &&
        !draft.signingRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!draft.isReplacingSecret ||
            !draft.newSecretKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
