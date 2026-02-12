import Foundation
import AWSS3
import AWSSDKIdentity

@MainActor
final class S3StorageClient: StorageClient {
    private let client: S3Client

    init(
        accessKeyId: String,
        secretAccessKey: String,
        endpointURL: String,
        signingRegion: String
    ) async throws {
        guard EndpointConfigValidator.isValidEndpointURL(endpointURL) else {
            throw StorageError.endpointUnreachable
        }
        guard EndpointConfigValidator.isValidRegion(signingRegion) else {
            throw StorageError.sdkError("Invalid signing region.")
        }

        // AWS SDK endpoint settings are consumed from process env by the runtime.
        // We set both generic and S3-specific vars for compatibility.
        setenv("AWS_ENDPOINT_URL", endpointURL, 1)
        setenv("AWS_ENDPOINT_URL_S3", endpointURL, 1)

        let credentials = AWSCredentialIdentity(
            accessKey: accessKeyId,
            secret: secretAccessKey,
            sessionToken: nil
        )

        let identityResolver = try StaticAWSCredentialIdentityResolver(credentials)
        let config = try await S3Client.S3ClientConfiguration(
            awsCredentialIdentityResolver: identityResolver,
            awsRetryMode: .standard,
            maxAttempts: 3,
            region: signingRegion
        )
        client = S3Client(config: config)
    }

    func listBuckets() async throws -> [BucketItem] {
        do {
            let output = try await client.listBuckets(input: ListBucketsInput())
            let result = (output.buckets ?? []).map {
                BucketItem(name: $0.name ?? "<unknown>", createdAt: $0.creationDate)
            }
            return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            throw map(error)
        }
    }

    private func map(_ error: Error) -> StorageError {
        let message = String(describing: error).lowercased()
        if message.contains("invalidaccesskeyid") || message.contains("signaturedoesnotmatch") {
            return .invalidCredentials
        }
        if message.contains("accessdenied") || message.contains("forbidden") {
            return .permissionDenied
        }
        if message.contains("not found") || message.contains("nosuchkey") {
            return .objectNotFound
        }
        if message.contains("timed out") || message.contains("could not connect") || message.contains("network") {
            return .endpointUnreachable
        }
        return .sdkError(String(describing: error))
    }
}
