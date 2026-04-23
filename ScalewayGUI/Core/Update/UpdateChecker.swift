import Foundation

struct UpdateInfo: Equatable {
    let version: String
    let releasePageURL: URL
    let downloadURL: URL?
}

enum UpdateChecker {
    private static let apiURL = URL(string:
        "https://api.github.com/repos/sevgjan/scaleway-storage-gui/releases/latest"
    )!

    static func checkForUpdates() async throws -> UpdateInfo? {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String
            enum CodingKeys: String, CodingKey {
                case name; case browserDownloadUrl = "browser_download_url"
            }
        }
        struct Release: Decodable {
            let tagName: String
            let htmlUrl: String
            let assets: [Asset]
            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"; case htmlUrl = "html_url"; case assets
            }
        }

        let release = try JSONDecoder().decode(Release.self, from: data)
        let latest = release.tagName.trimmingCharacters(in: .init(charactersIn: "v"))
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        guard latest.compare(current, options: .numeric) == .orderedDescending else { return nil }

        guard let pageURL = URL(string: release.htmlUrl) else { return nil }
        let dmgAsset = release.assets.first { $0.name.hasSuffix(".dmg") }
        return UpdateInfo(
            version: latest,
            releasePageURL: pageURL,
            downloadURL: dmgAsset.flatMap { URL(string: $0.browserDownloadUrl) }
        )
    }
}
