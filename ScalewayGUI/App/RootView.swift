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
        .safeAreaInset(edge: .bottom) { toast }
        .task(id: store.bannerMessage) {
            guard let banner = store.bannerMessage else { return }
            try? await Task.sleep(for: .seconds(2.5))
            if store.bannerMessage == banner {
                store.bannerMessage = nil
            }
        }
    }

    private var sidebar: some View {
        List(selection: $store.selectedSidebarItem) {
            Section {
                ForEach(store.accounts) { account in
                    AccountRow(
                        account: account,
                        isActive: store.selectedAccount?.id == account.id
                    )
                        .tag(SidebarItem.account(account.id))
                        .contextMenu {
                            Button("Delete Account", role: .destructive) {
                                Task { @MainActor in
                                    await store.deleteAccount(account)
                                }
                            }
                        }
                }
            } header: {
                Label("Accounts", systemImage: "person.2.fill")
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
                Label("Refresh Buckets", systemImage: "arrow.clockwise")
            }
            .disabled(store.selectedAccount == nil)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { @MainActor in
                    await store.loadObjectsForSelectedBucket()
                }
            } label: {
                Label("Refresh Objects", systemImage: "arrow.clockwise.circle")
            }
            .disabled(store.selectedBucketName == nil)
        }
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
}
