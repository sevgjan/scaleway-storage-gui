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
                            .contextMenu {
                                Button("Delete Account", role: .destructive) {
                                    Task { @MainActor in
                                        await store.deleteAccount(account)
                                    }
                                }
                            }
                    }
                }

                Section("Buckets") {
                    ForEach(store.buckets) { bucket in
                        HStack {
                            Text(bucket.name)
                            if store.isLoadingBucketObjects && store.loadingBucketName == bucket.name {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .tag(SidebarItem.bucket(bucket.name))
                    }
                }
            }
            .frame(minWidth: 220)
        } detail: {
            if store.selectedBucketName != nil {
                BucketObjectsView(store: store)
            } else {
                AccountSetupView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Scaleway Object Storage")
        .onChange(of: store.selectedSidebarItem) { _, _ in
            Task { @MainActor in
                await store.handleSidebarSelectionChange()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh Buckets") {
                    Task { @MainActor in
                        await store.refreshBucketsForSelectedAccount()
                    }
                }
                .disabled(store.selectedAccount == nil)
            }
            ToolbarItem(placement: .automatic) {
                Button("Refresh Objects") {
                    Task { @MainActor in
                        await store.loadObjectsForSelectedBucket()
                    }
                }
                .disabled(store.selectedBucketName == nil)
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

private struct BucketObjectsView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bucket: " + (store.selectedBucketName ?? ""))
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(store.breadcrumbItems.enumerated()), id: \.element.id) { index, crumb in
                        Button(crumb.title) {
                            Task { @MainActor in
                                await store.navigateToPrefix(crumb.prefix)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary.opacity(0.45))
                        )

                        if index < store.breadcrumbItems.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search in current folder", text: $store.objectSearchQuery)
                    .textFieldStyle(.plain)
                if !store.objectSearchQuery.isEmpty {
                    Button {
                        store.objectSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary.opacity(0.4))
            )

            if store.filteredObjectItems.isEmpty {
                ContentUnavailableView(
                    "No Objects",
                    systemImage: "tray",
                    description: Text("This bucket appears empty at the current prefix.")
                )
            } else {
                List(store.filteredObjectItems) { item in
                    Button {
                        Task { @MainActor in
                            await store.openObjectItem(item)
                        }
                    } label: {
                        HStack {
                            Image(systemName: item.isFolder ? "folder" : "doc")
                                .foregroundStyle(item.isFolder ? .yellow : .secondary)
                            Text(item.displayName)
                            Spacer()
                            if !item.isFolder {
                                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
