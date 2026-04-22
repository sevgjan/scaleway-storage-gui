import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
        .onDrop(of: [.fileURL], isTargeted: $store.isDropTargeted) { providers in
            guard store.selectedBucketName != nil else { return false }
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    if let url = try? await loadFileURL(from: provider) {
                        urls.append(url)
                    }
                }
                if !urls.isEmpty {
                    await store.uploadFiles(at: urls)
                }
            }
            return true
        }
        .overlay {
            if store.isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.06))
                    )
                    .overlay(
                        Label(
                            "Drop to upload to \(store.currentPrefix.isEmpty ? "/" : store.currentPrefix)",
                            systemImage: "square.and.arrow.up"
                        )
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    )
                    .allowsHitTesting(false)
                    .padding(6)
            }
        }
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
            if store.selectedBucketName != nil {
                Button {
                    presentUploadPanel()
                } label: {
                    Label("Upload", systemImage: "arrow.up.circle")
                }
                .buttonStyle(.borderless)
                .help("Upload files to \(store.currentPrefix.isEmpty ? "bucket root" : store.currentPrefix)")
            }
        }
    }

    private func presentUploadPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Upload"
        panel.message = "Select files to upload"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { @MainActor in
            await store.uploadFiles(at: urls)
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url {
                    cont.resume(returning: url)
                } else {
                    cont.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
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
