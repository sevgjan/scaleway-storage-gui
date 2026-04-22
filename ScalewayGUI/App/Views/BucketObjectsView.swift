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
        .sheet(item: $store.previewItem, onDismiss: {
            store.closePreview()
        }) { item in
            QuickLookPreviewSheet(item: item)
        }
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
                HStack(spacing: 8) {
                    Button {
                        Task { @MainActor in
                            await store.openObjectItem(item)
                        }
                    } label: {
                        ObjectRow(item: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ObjectCellButtonStyle())

                    if let date = item.lastModified {
                        Text(date, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }

                    if !item.isFolder {
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    if item.isFolder {
                        Button {
                            Task { @MainActor in
                                await store.downloadFolderItem(item)
                            }
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .help("Download Folder")
                    }

                    if !item.isFolder && item.isPreviewSupported {
                        Button {
                            Task { @MainActor in
                                await store.previewObjectItem(item)
                            }
                        } label: {
                            Image(systemName: "eye")
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .help("Quick Look Preview")
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct ObjectCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.16) : Color.clear)
            )
    }
}
