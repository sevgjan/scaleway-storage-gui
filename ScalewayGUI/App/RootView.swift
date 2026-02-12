import SwiftUI

struct RootView: View {
    @Bindable var store: AppStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedSidebarItem) {
                Section("Accounts") {
                    ForEach(store.accounts) { account in
                        Text(account.displayName)
                            .tag(SidebarItem.account(account.id))
                    }
                }

                Section("Buckets") {
                    ForEach(store.buckets) { bucket in
                        Text(bucket.name)
                            .tag(SidebarItem.bucket(bucket.name))
                    }
                }
            }
            .frame(minWidth: 220)
        } detail: {
            AccountSetupView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Scaleway Object Storage")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh Buckets") {
                    Task { @MainActor in
                        await store.refreshBucketsForSelectedAccount()
                    }
                }
                .disabled(store.selectedAccount == nil)
            }
        }
        .overlay(alignment: .top) {
            if let banner = store.bannerMessage {
                Text(banner)
                    .font(.callout)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 10)
            }
        }
    }
}
