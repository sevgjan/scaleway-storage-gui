import SwiftUI

struct AccountSetupView: View {
    @Bindable var store: AppStore
    @State private var draft = AccountDraft()
    var onDismiss: (() -> Void)? = nil

    private let endpointPresets: [(label: String, endpoint: String, region: String)] = [
        ("NL Amsterdam", "https://s3.nl-ams.scw.cloud", "nl-ams"),
        ("FR Paris", "https://s3.fr-par.scw.cloud", "fr-par"),
        ("PL Warsaw", "https://s3.pl-waw.scw.cloud", "pl-waw")
    ]

    var body: some View {
        Form {
            Section("Account") {
                TextField("Display Name", text: $draft.displayName)
                TextField("Access Key ID", text: $draft.accessKeyId)
                SecureField("Secret Access Key", text: $draft.secretKey)
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
                        let ok = await store.addAccountAndValidate(draft)
                        if ok { onDismiss?() }
                    }
                }
                .disabled(!canSubmit || store.isBusy)

                if onDismiss != nil {
                    Button("Cancel") {
                        onDismiss?()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var canSubmit: Bool {
        !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.secretKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: draft.endpointURL) != nil &&
        !draft.signingRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
