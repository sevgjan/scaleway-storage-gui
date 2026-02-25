import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class AppStore {
    var accounts: [AccountProfile] = []
    var selectedAccount: AccountProfile?
    var selectedSidebarItem: SidebarItem?
    var buckets: [BucketItem] = []
    var selectedBucketName: String?
    var objectItems: [ObjectItem] = []
    var currentPrefix = ""
    var objectSearchQuery = ""
    var isLoadingBucketObjects = false
    var loadingBucketName: String?
    var isBusy = false
    var bannerMessage: String?
    var previewItem: PreviewItem?

    private let accountStore: AccountStore
    private let keychainService: KeychainServicing
    private let storageClientBuilder: StorageClientBuilding
    private let logger = AppLogger.logger

    init(
        accountStore: AccountStore = AccountStore(),
        keychainService: KeychainServicing = KeychainService(),
        storageClientBuilder: StorageClientBuilding? = nil
    ) {
        self.accountStore = accountStore
        self.keychainService = keychainService
        self.storageClientBuilder = storageClientBuilder ?? StorageClientBuilder()
        loadAccounts()
    }

    func loadAccounts() {
        do {
            accounts = try accountStore.load()
            selectedAccount = accounts.first
            selectedSidebarItem = selectedAccount.map { .account($0.id) }

            if selectedAccount != nil {
                Task { @MainActor in
                    await refreshBucketsForSelectedAccount()
                }
            }
        } catch {
            bannerMessage = "Failed to load accounts."
            logger.error("Failed loading accounts: \(error.localizedDescription, privacy: .public)")
        }
    }

    func addAccountAndValidate(_ draft: AccountDraft) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let secretRef = try keychainService.saveSecret(draft.secretKey)
            let profile = AccountProfile(
                displayName: draft.displayName,
                accessKeyId: draft.accessKeyId,
                secretKeyRef: secretRef,
                endpointURL: draft.endpointURL,
                signingRegion: draft.signingRegion
            )

            let secret = try keychainService.readSecret(for: profile.secretKeyRef)
            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: profile.accessKeyId,
                secretAccessKey: secret,
                endpointURL: profile.endpointURL,
                signingRegion: profile.signingRegion
            )
            let bucketList = try await storageClient.listBuckets()

            try accountStore.upsert(profile)
            accounts = try accountStore.load()
            selectedAccount = profile
            buckets = bucketList
            bannerMessage = "Connection successful. Found \(bucketList.count) buckets."
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Account setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshBucketsForSelectedAccount() async {
        guard let account = selectedAccount else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let secret = try keychainService.readSecret(for: account.secretKeyRef)
            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: account.accessKeyId,
                secretAccessKey: secret,
                endpointURL: account.endpointURL,
                signingRegion: account.signingRegion
            )
            buckets = try await storageClient.listBuckets()
            bannerMessage = "Buckets refreshed."
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func handleSidebarSelectionChange() async {
        guard let selection = selectedSidebarItem else { return }
        switch selection {
        case .account(let id):
            selectedAccount = accounts.first(where: { $0.id == id })
            selectedBucketName = nil
            objectItems = []
            currentPrefix = ""
            objectSearchQuery = ""
            isLoadingBucketObjects = false
            loadingBucketName = nil
            buckets = []
            await refreshBucketsForSelectedAccount()
        case .bucket(let bucketName):
            selectedBucketName = bucketName
            currentPrefix = ""
            objectSearchQuery = ""
            loadingBucketName = bucketName
            await loadObjectsForSelectedBucket()
        }
    }

    func deleteAccount(_ account: AccountProfile) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try keychainService.deleteSecret(for: account.secretKeyRef)
            try accountStore.delete(id: account.id)

            accounts = try accountStore.load()
            if selectedAccount?.id == account.id {
                selectedAccount = accounts.first
            }

            selectedSidebarItem = selectedAccount.map { .account($0.id) }
            selectedBucketName = nil
            objectItems = []
            currentPrefix = ""
            objectSearchQuery = ""

            if selectedAccount != nil {
                await refreshBucketsForSelectedAccount()
            } else {
                buckets = []
            }

            bannerMessage = "Account deleted."
        } catch {
            bannerMessage = "Failed to delete account."
            logger.error("Delete account failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadObjectsForSelectedBucket() async {
        guard let account = selectedAccount, let bucketName = selectedBucketName else { return }
        isBusy = true
        isLoadingBucketObjects = true
        loadingBucketName = bucketName
        defer {
            isBusy = false
            isLoadingBucketObjects = false
            loadingBucketName = nil
        }

        do {
            let secret = try keychainService.readSecret(for: account.secretKeyRef)
            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: account.accessKeyId,
                secretAccessKey: secret,
                endpointURL: account.endpointURL,
                signingRegion: account.signingRegion
            )
            objectItems = try await storageClient.listObjects(
                bucket: bucketName,
                prefix: currentPrefix.isEmpty ? nil : currentPrefix,
                delimiter: "/"
            )
            bannerMessage = "Loaded \(objectItems.count) items in \(bucketName)."
        } catch {
            objectItems = []
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Load objects failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func openObjectItem(_ item: ObjectItem) async {
        if item.isFolder {
            currentPrefix = item.key
            await loadObjectsForSelectedBucket()
            return
        }
        await downloadObjectItem(item)
    }

    func previewObjectItem(_ item: ObjectItem) async {
        guard !item.isFolder else { return }
        guard item.isPreviewSupported else {
            bannerMessage = "Preview is not supported for this file type."
            return
        }
        // Avoid loading extremely large objects into memory for inline preview.
        if item.size > 50 * 1024 * 1024 {
            bannerMessage = "File is too large for preview. Please download it."
            return
        }
        guard let account = selectedAccount, let bucketName = selectedBucketName else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            let secret = try keychainService.readSecret(for: account.secretKeyRef)
            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: account.accessKeyId,
                secretAccessKey: secret,
                endpointURL: account.endpointURL,
                signingRegion: account.signingRegion
            )

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ScalewayGUI-QuickLook", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let fileURL = tempDir
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(item.fileExtension.isEmpty ? "tmp" : item.fileExtension)

            try await storageClient.downloadObject(
                bucket: bucketName,
                key: item.key,
                to: fileURL
            )

            previewItem = PreviewItem(url: fileURL, title: item.displayName)
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Preview download failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func closePreview() {
        previewItem = nil
    }

    func navigateToPrefix(_ prefix: String) async {
        currentPrefix = prefix
        await loadObjectsForSelectedBucket()
    }

    var breadcrumbItems: [BreadcrumbItem] {
        var result: [BreadcrumbItem] = [BreadcrumbItem(title: "Root", prefix: "")]
        guard !currentPrefix.isEmpty else { return result }

        let parts = currentPrefix.split(separator: "/").map(String.init)
        var built = ""
        for part in parts {
            built += part + "/"
            result.append(BreadcrumbItem(title: part, prefix: built))
        }
        return result
    }

    var filteredObjectItems: [ObjectItem] {
        let trimmed = objectSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return objectItems }
        return objectItems.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed) ||
            $0.key.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func downloadFolderItem(_ item: ObjectItem) async {
        guard item.isFolder else { return }
        guard let account = selectedAccount, let bucketName = selectedBucketName else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Download Here"
        panel.message = "Choose a destination for \"\(item.displayName)\""

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            let secret = try keychainService.readSecret(for: account.secretKeyRef)
            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: account.accessKeyId,
                secretAccessKey: secret,
                endpointURL: account.endpointURL,
                signingRegion: account.signingRegion
            )

            let allObjects = try await storageClient.listObjects(
                bucket: bucketName,
                prefix: item.key,
                delimiter: nil
            )
            let fileObjects = allObjects.filter { !$0.isFolder }

            for object in fileObjects {
                let relativePath = String(object.key.dropFirst(item.key.count))
                let fileURL = destinationURL
                    .appendingPathComponent(item.displayName)
                    .appendingPathComponent(relativePath)
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try await storageClient.downloadObject(
                    bucket: bucketName,
                    key: object.key,
                    to: fileURL
                )
            }

            bannerMessage = "Downloaded \(fileObjects.count) file(s) from \"\(item.displayName)\"."
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Folder download failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func downloadObjectItem(_ item: ObjectItem) async {
        guard let account = selectedAccount, let bucketName = selectedBucketName else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.displayName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            let secret = try keychainService.readSecret(for: account.secretKeyRef)
            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: account.accessKeyId,
                secretAccessKey: secret,
                endpointURL: account.endpointURL,
                signingRegion: account.signingRegion
            )
            try await storageClient.downloadObject(
                bucket: bucketName,
                key: item.key,
                to: destinationURL
            )
            bannerMessage = "Downloaded \(item.displayName)."
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Download failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum SidebarItem: Hashable {
    case account(UUID)
    case bucket(String)
}

struct BreadcrumbItem: Identifiable, Equatable {
    var id: String { prefix }
    let title: String
    let prefix: String
}

struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}
