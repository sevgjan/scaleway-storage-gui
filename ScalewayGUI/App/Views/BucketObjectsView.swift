import SwiftUI

struct BucketObjectsView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            BreadcrumbBar(store: store)
            SearchBar(text: $store.objectSearchQuery)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Text(store.selectedBucketName ?? "")
                .font(.title3.weight(.semibold))
            Spacer()
            Text("\(store.filteredObjectItems.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.filteredObjectItems.isEmpty {
            ContentUnavailableView(
                "No Objects",
                systemImage: "tray",
                description: Text("This bucket appears empty at the current prefix.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(store.filteredObjectItems) { item in
                Button {
                    Task { @MainActor in
                        await store.openObjectItem(item)
                    }
                } label: {
                    ObjectRow(item: item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }
}
