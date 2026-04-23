import Foundation
import Observation
import AppKit

enum UpdateState: Equatable {
    case none
    case available(UpdateInfo)
    case downloading(progress: Double, version: String)
    case ready(mountPoint: URL, version: String)
    case failed(String)
}

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
    var isDropTargeted = false
    var editingAccount: AccountProfile?
    var pendingDeleteAccount: AccountProfile?
    var isCreatingAccount = false
    var uploadProgress: UploadProgress?
    var updateState: UpdateState = .none

    private var updater: Updater?
    private var pendingUpdateInfo: UpdateInfo?
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

    @discardableResult
    func addAccountAndValidate(_ draft: AccountDraft) async -> Bool {
        isBusy = true
        defer { isBusy = false }

        var createdSecretRef: String?
        do {
            let secretRef = try keychainService.saveSecret(draft.secretKey)
            createdSecretRef = secretRef

            let profile = AccountProfile(
                displayName: draft.displayName,
                accessKeyId: draft.accessKeyId,
                secretKeyRef: secretRef,
                endpointURL: draft.endpointURL,
                signingRegion: draft.signingRegion
            )

            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: profile.accessKeyId,
                secretAccessKey: draft.secretKey,
                endpointURL: profile.endpointURL,
                signingRegion: profile.signingRegion
            )
            let bucketList = try await storageClient.listBuckets()

            try accountStore.upsert(profile)
            accounts = try accountStore.load()
            selectedAccount = profile
            buckets = bucketList
            bannerMessage = "Connection successful. Found \(bucketList.count) buckets."
            return true
        } catch {
            if let ref = createdSecretRef {
                try? keychainService.deleteSecret(for: ref)
            }
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Account setup failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    func updateAccount(_ draft: AccountEditDraft) async -> Bool {
        guard let original = accounts.first(where: { $0.id == draft.id }) else {
            bannerMessage = "Account not found."
            return false
        }

        isBusy = true
        defer { isBusy = false }

        do {
            var updated = original
            updated.displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.accessKeyId = draft.accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.endpointURL = draft.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.signingRegion = draft.signingRegion.trimmingCharacters(in: .whitespacesAndNewlines)

            let validationSecret: String
            if draft.isReplacingSecret {
                validationSecret = draft.newSecretKey
            } else {
                validationSecret = try keychainService.readSecret(for: updated.secretKeyRef)
            }

            let client = try await storageClientBuilder.makeClient(
                accessKeyId: updated.accessKeyId,
                secretAccessKey: validationSecret,
                endpointURL: updated.endpointURL,
                signingRegion: updated.signingRegion
            )
            _ = try await client.listBuckets()

            if draft.isReplacingSecret {
                try keychainService.updateSecret(for: updated.secretKeyRef, to: draft.newSecretKey)
            }
            try accountStore.upsert(updated)

            accounts = try accountStore.load()
            if selectedAccount?.id == updated.id {
                selectedAccount = updated
                await refreshBucketsForSelectedAccount()
            }

            bannerMessage = "Account \"\(updated.displayName)\" updated."
            return true
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Account update failed: \(error.localizedDescription, privacy: .public)")
            return false
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

    func uploadFiles(at sourceURLs: [URL]) async {
        guard let account = selectedAccount, let bucketName = selectedBucketName else {
            bannerMessage = "Select a bucket before uploading."
            return
        }

        struct PendingUpload {
            let url: URL
            let key: String
        }

        var uploads: [PendingUpload] = []
        for url in sourceURLs {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let folderName = url.lastPathComponent
                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                while let fileURL = enumerator.nextObject() as? URL {
                    let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    if values?.isDirectory == true { continue }

                    let relative = String(fileURL.path.dropFirst(url.path.count))
                    let normalized = relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
                    let key = currentPrefix + folderName + "/" + normalized
                    uploads.append(PendingUpload(url: fileURL, key: key))
                }
            } else {
                let key = currentPrefix + url.lastPathComponent
                uploads.append(PendingUpload(url: url, key: key))
            }
        }

        guard !uploads.isEmpty else {
            bannerMessage = "No files to upload."
            return
        }

        let existingKeys = Set(objectItems.filter { !$0.isFolder }.map { $0.key })
        let conflicts = uploads.filter { existingKeys.contains($0.key) }
        if !conflicts.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Overwrite \(conflicts.count) existing file(s)?"
            let listed = conflicts.prefix(5).map { $0.url.lastPathComponent }.joined(separator: "\n")
            let more = conflicts.count > 5 ? "\n…and \(conflicts.count - 5) more" : ""
            alert.informativeText = listed + more
            alert.addButton(withTitle: "Overwrite")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }

        isBusy = true
        uploadProgress = UploadProgress(completed: 0, total: uploads.count, currentName: nil)
        defer {
            isBusy = false
            uploadProgress = nil
        }

        do {
            let secret = try keychainService.readSecret(for: account.secretKeyRef)
            let storageClient = try await storageClientBuilder.makeClient(
                accessKeyId: account.accessKeyId,
                secretAccessKey: secret,
                endpointURL: account.endpointURL,
                signingRegion: account.signingRegion
            )

            for (index, pending) in uploads.enumerated() {
                uploadProgress = UploadProgress(
                    completed: index,
                    total: uploads.count,
                    currentName: pending.url.lastPathComponent
                )
                try await storageClient.uploadObject(bucket: bucketName, key: pending.key, from: pending.url)
            }

            uploadProgress = UploadProgress(
                completed: uploads.count,
                total: uploads.count,
                currentName: nil
            )
            bannerMessage = "Uploaded \(uploads.count) file(s)."
            await loadObjectsForSelectedBucket()
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func createFolder(named rawName: String) async {
        guard let account = selectedAccount, let bucketName = selectedBucketName else {
            bannerMessage = "Select a bucket first."
            return
        }
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleaned.isEmpty else {
            bannerMessage = "Folder name can't be empty."
            return
        }

        let key = currentPrefix + cleaned + "/"

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

            let marker = FileManager.default.temporaryDirectory
                .appendingPathComponent("scaleway-empty-\(UUID().uuidString)")
            try Data().write(to: marker, options: .atomic)
            defer { try? FileManager.default.removeItem(at: marker) }

            try await storageClient.uploadObject(bucket: bucketName, key: key, from: marker)

            bannerMessage = "Created folder \"\(cleaned)\"."
            await loadObjectsForSelectedBucket()
        } catch {
            bannerMessage = StorageErrorMapper.userMessage(for: error)
            logger.error("Create folder failed: \(error.localizedDescription, privacy: .public)")
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

    // MARK: - Updates

    func checkForUpdates() async {
        guard let info = try? await UpdateChecker.checkForUpdates() else { return }
        updateState = .available(info)
    }

    func startUpdateDownload(_ info: UpdateInfo) {
        guard let dmgURL = info.downloadURL else {
            NSWorkspace.shared.open(info.releasePageURL)
            return
        }
        let u = Updater()
        updater = u
        pendingUpdateInfo = info
        updateState = .downloading(progress: 0, version: info.version)
        Task {
            await u.download(url: dmgURL) { [weak self] progress in
                self?.updateState = .downloading(progress: progress, version: info.version)
            } onComplete: { [weak self] mountPoint in
                self?.updateState = .ready(mountPoint: mountPoint, version: info.version)
            } onError: { [weak self] msg in
                self?.updateState = .failed(msg)
            }
        }
    }

    func cancelUpdateDownload() {
        updater?.cancel()
        updater = nil
        if let info = pendingUpdateInfo {
            updateState = .available(info)
        } else {
            updateState = .none
        }
    }

    func dismissUpdate() {
        updater?.cancel()
        updater = nil
        pendingUpdateInfo = nil
        updateState = .none
    }

    func applyUpdate(mountPoint: URL) {
        updater?.install(mountPoint: mountPoint)
        NSApplication.shared.terminate(nil)
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

struct UploadProgress: Equatable {
    var completed: Int
    var total: Int
    var currentName: String?

    var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
}
