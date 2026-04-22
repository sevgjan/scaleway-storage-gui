import Foundation

struct AccountProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var accessKeyId: String
    var secretKeyRef: String
    var endpointURL: String
    var signingRegion: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        accessKeyId: String,
        secretKeyRef: String,
        endpointURL: String,
        signingRegion: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.accessKeyId = accessKeyId
        self.secretKeyRef = secretKeyRef
        self.endpointURL = endpointURL
        self.signingRegion = signingRegion
        self.createdAt = createdAt
    }
}

struct AccountDraft {
    var displayName: String = ""
    var accessKeyId: String = ""
    var secretKey: String = ""
    var endpointURL: String = "https://s3.nl-ams.scw.cloud"
    var signingRegion: String = "nl-ams"
}

struct AccountEditDraft {
    var id: UUID
    var displayName: String
    var accessKeyId: String
    var endpointURL: String
    var signingRegion: String
    var secretKeyRef: String
    var isReplacingSecret: Bool = false
    var newSecretKey: String = ""

    init(from profile: AccountProfile) {
        self.id = profile.id
        self.displayName = profile.displayName
        self.accessKeyId = profile.accessKeyId
        self.endpointURL = profile.endpointURL
        self.signingRegion = profile.signingRegion
        self.secretKeyRef = profile.secretKeyRef
    }
}
