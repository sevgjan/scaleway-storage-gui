import SwiftUI

struct RootView: View {
    @Bindable var store: AppStore

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle("Scaleway Object Storage")
        .onChange(of: store.selectedSidebarItem) { _, _ in
            Task { @MainActor in
                await store.handleSidebarSelectionChange()
            }
        }
        .toolbar { toolbar }
        .task {
            await store.checkForUpdates()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                ForEach(store.uploadBatches) { batch in
                    uploadBanner(batch)
                }
                updateBanner
                toast
            }
        }
        .onChange(of: store.updateState) { _, new in
            if case .failed(let msg) = new {
                store.bannerMessage = msg
                store.updateState = .none
            }
        }
        .task(id: store.bannerMessage) {
            guard let banner = store.bannerMessage else { return }
            try? await Task.sleep(for: .seconds(2.5))
            if store.bannerMessage == banner {
                store.bannerMessage = nil
            }
        }
        .sheet(item: $store.editingAccount) { account in
            AccountEditView(
                store: store,
                draft: AccountEditDraft(from: account),
                onDismiss: { store.editingAccount = nil }
            )
        }
        .sheet(isPresented: $store.isCreatingAccount) {
            AccountSetupView(
                store: store,
                onDismiss: { store.isCreatingAccount = false }
            )
            .frame(minWidth: 480, minHeight: 520)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { store.pendingDeleteAccount != nil },
                set: { if !$0 { store.pendingDeleteAccount = nil } }
            ),
            titleVisibility: .visible,
            presenting: store.pendingDeleteAccount
        ) { account in
            Button("Delete Account", role: .destructive) {
                Task { @MainActor in
                    await store.deleteAccount(account)
                    store.pendingDeleteAccount = nil
                }
            }
            Button("Cancel", role: .cancel) {
                store.pendingDeleteAccount = nil
            }
        } message: { _ in
            Text("Removes the profile and its Keychain entry. This cannot be undone.")
        }
    }

    private var deleteDialogTitle: String {
        store.pendingDeleteAccount.map { "Delete \"\($0.displayName)\"?" } ?? ""
    }

    private var sidebar: some View {
        List(selection: $store.selectedSidebarItem) {
            Section {
                ForEach(store.accounts) { account in
                    AccountRow(
                        account: account,
                        isActive: store.selectedAccount?.id == account.id,
                        onEdit: { store.editingAccount = account }
                    )
                        .tag(SidebarItem.account(account.id))
                        .contextMenu {
                            Button("Edit Account…") {
                                store.editingAccount = account
                            }
                            Button("Delete Account", role: .destructive) {
                                store.pendingDeleteAccount = account
                            }
                        }
                }
            } header: {
                HStack {
                    Label("Accounts", systemImage: "person.2.fill")
                        .font(.title3.weight(.semibold))
                        .textCase(nil)
                    Spacer()
                    Button {
                        store.isCreatingAccount = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.accentColor)
                    .help("Add Account")
                }
                .padding(.vertical, 8)
                .padding(.trailing, 4)
            }

            Section {
                ForEach(store.buckets) { bucket in
                    BucketRow(
                        name: bucket.name,
                        isLoading: store.isLoadingBucketObjects && store.loadingBucketName == bucket.name
                    )
                    .tag(SidebarItem.bucket(bucket.name))
                }
            } header: {
                Label("Buckets", systemImage: "externaldrive.fill")
                    .font(.title3.weight(.semibold))
                    .textCase(nil)
                    .padding(.vertical, 8)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .frame(minWidth: 250)
    }

    @ViewBuilder
    private var detail: some View {
        if store.selectedBucketName != nil {
            BucketObjectsView(store: store)
        } else if store.selectedAccount != nil {
            AccountHomeView(store: store)
        } else {
            AccountSetupView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { @MainActor in
                    await store.refreshBucketsForSelectedAccount()
                }
            } label: {
                Label("Refresh Buckets", systemImage: "externaldrive.badge.icloud")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(store.selectedAccount == nil)
            .help("Refresh the list of buckets for the selected account")
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { @MainActor in
                    await store.loadObjectsForSelectedBucket()
                }
            } label: {
                Label("Refresh Objects", systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(store.selectedBucketName == nil)
            .help("Refresh objects in the current bucket and folder")
        }
    }

    @ViewBuilder
    private func uploadBanner(_ batch: UploadBatch) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(.tint)
                Text(batch.isQueued ? "Queued — \"\(batch.name)\"" : "\"\(batch.name)\" — \(batch.completed) of \(batch.total)")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(Int(batch.fraction * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let name = batch.currentName {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            ProgressView(value: batch.fraction)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private var toast: some View {
        if let banner = store.bannerMessage {
            HStack {
                Spacer()
                Label(banner, systemImage: "info.circle.fill")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var updateBanner: some View {
        switch store.updateState {
        case .available(let info):
            updateAvailableBanner(info)
        case .downloading(let progress, let version):
            updateDownloadingBanner(progress: progress, version: version)
        case .ready(let mountPoint, let version):
            updateReadyBanner(mountPoint: mountPoint, version: version)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func updateAvailableBanner(_ info: UpdateInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("Update Available — v\(info.version)")
                    .font(.callout.weight(.semibold))
                Text("A new version is ready to download")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Update") {
                store.startUpdateDownload(info)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .fontWeight(.semibold)
            Button {
                store.dismissUpdate()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private func updateDownloadingBanner(progress: Double, version: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue)
                Text("Downloading v\(version)")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Cancel") {
                    store.cancelUpdateDownload()
                }
                .controlSize(.small)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private func updateReadyBanner(mountPoint: URL, version: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("v\(version) ready to install")
                    .font(.callout.weight(.semibold))
                Text("The app will restart to apply the update")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restart & Update") {
                store.applyUpdate(mountPoint: mountPoint)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .fontWeight(.semibold)
            .tint(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: 420)
    }
}
