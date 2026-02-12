import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var accounts: [AccountProfile] = []
    var selectedAccount: AccountProfile?
    var selectedSidebarItem: SidebarItem?
    var buckets: [BucketItem] = []
    var isBusy = false
    var bannerMessage: String?

    private let accountStore: AccountStore
    private let keychainService: KeychainServicing
    private let storageClientBuilder: StorageClientBuilding
    private let logger = AppLogger.logger

    init(
        accountStore: AccountStore = AccountStore(),
        keychainService: KeychainServicing = KeychainService(),
        storageClientBuilder: StorageClientBuilding = StorageClientBuilder()
    ) {
        self.accountStore = accountStore
        self.keychainService = keychainService
        self.storageClientBuilder = storageClientBuilder
        loadAccounts()
    }

    func loadAccounts() {
        do {
            accounts = try accountStore.load()
            selectedAccount = accounts.first
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
}

enum SidebarItem: Hashable {
    case account(UUID)
    case bucket(String)
}
