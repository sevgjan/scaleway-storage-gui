import Foundation

struct ObjectItem: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let size: Int64
    let lastModified: Date?
    let isFolder: Bool

    var displayName: String {
        let trimmed = key.hasSuffix("/") ? String(key.dropLast()) : key
        return trimmed.split(separator: "/").last.map(String.init) ?? key
    }

    var fileExtension: String {
        URL(fileURLWithPath: displayName).pathExtension.lowercased()
    }

    var isPreviewSupported: Bool {
        let supported = Set(["json", "pdf", "jpg", "jpeg", "png", "log", "txt", "usdz"])
        return supported.contains(fileExtension)
    }
}
