import SwiftUI
import PDFKit
import SceneKit
import AppKit

struct QuickLookPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: PreviewItem

    private var fileExtension: String {
        item.url.pathExtension.lowercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Close Preview")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            previewBody
                .frame(minWidth: 760, minHeight: 520)
        }
    }

    @ViewBuilder
    private var previewBody: some View {
        switch fileExtension {
        case "jpg", "jpeg", "png":
            ImagePreview(url: item.url)
        case "pdf":
            PDFPreview(url: item.url)
        case "json", "log", "txt":
            TextPreview(url: item.url)
        case "usdz":
            USDZPreview(url: item.url)
        default:
            UnsupportedPreview(url: item.url)
        }
    }
}

private struct ImagePreview: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                GeometryReader { proxy in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .background(Color.black.opacity(0.04))
                }
            } else {
                Text("Unable to load image preview.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView(frame: .zero)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document == nil {
            nsView.document = PDFDocument(url: url)
        }
    }
}

private struct TextPreview: View {
    let url: URL
    @State private var content = ""

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .background(Color.black.opacity(0.03))
        .task(id: url) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                content = text
            } else {
                content = "Unable to decode file as UTF-8 text."
            }
        }
    }
}

private struct USDZPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.backgroundColor = .clear

        if let scene = try? SCNScene(url: url, options: nil) {
            view.scene = scene
        }
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        if nsView.scene == nil {
            nsView.scene = try? SCNScene(url: url, options: nil)
        }
    }
}

private struct UnsupportedPreview: View {
    let url: URL

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "eye.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Preview is unavailable for this file type.")
                .foregroundStyle(.secondary)
            Button("Open in Default App") {
                NSWorkspace.shared.open(url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
