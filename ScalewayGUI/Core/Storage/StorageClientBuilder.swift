import Foundation

@MainActor
protocol StorageClientBuilding {
    func makeClient(
        accessKeyId: String,
        secretAccessKey: String,
        endpointURL: String,
        signingRegion: String
    ) async throws -> StorageClient
}

@MainActor
struct StorageClientBuilder: StorageClientBuilding {
    func makeClient(
        accessKeyId: String,
        secretAccessKey: String,
        endpointURL: String,
        signingRegion: String
    ) async throws -> StorageClient {
        try await S3StorageClient(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            endpointURL: endpointURL,
            signingRegion: signingRegion
        )
    }
}
