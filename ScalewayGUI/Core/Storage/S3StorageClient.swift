import Foundation
import AWSS3
import AWSSDKIdentity
import SmithyStreams

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

    func listObjects(bucket: String, prefix: String?, delimiter: String?) async throws -> [ObjectItem] {
        do {
            let output = try await client.listObjectsV2(
                input: ListObjectsV2Input(
                    bucket: bucket,
                    delimiter: delimiter,
                    maxKeys: 1000,
                    prefix: prefix
                )
            )

            let folderItems: [ObjectItem] = (output.commonPrefixes ?? []).compactMap { prefixItem in
                guard let key = prefixItem.prefix else { return nil }
                return ObjectItem(key: key, size: 0, lastModified: nil, isFolder: true)
            }

            let fileItems: [ObjectItem] = (output.contents ?? []).compactMap { item in
                guard let key = item.key else { return nil }
                if key == prefix { return nil }
                return ObjectItem(
                    key: key,
                    size: Int64(item.size ?? 0),
                    lastModified: item.lastModified,
                    isFolder: key.hasSuffix("/")
                )
            }

            return (folderItems + fileItems).sorted { lhs, rhs in
                if lhs.isFolder != rhs.isFolder {
                    return lhs.isFolder && !rhs.isFolder
                }
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
        } catch {
            throw map(error)
        }
    }

    func downloadObject(bucket: String, key: String, to destinationURL: URL) async throws {
        do {
            let output = try await client.getObject(
                input: GetObjectInput(
                    bucket: bucket,
                    key: key
                )
            )
            guard let body = output.body else {
                throw StorageError.sdkError("Object body was empty.")
            }
            guard let data = try await body.readData() else {
                throw StorageError.sdkError("Unable to read object data.")
            }
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            if let mapped = error as? StorageError {
                throw mapped
            }
            throw map(error)
        }
    }

    func uploadObject(bucket: String, key: String, from sourceURL: URL) async throws {
        do {
            let fileHandle = try FileHandle(forReadingFrom: sourceURL)
            defer { try? fileHandle.close() }
            _ = try await client.putObject(
                input: PutObjectInput(
                    body: .stream(FileStream(fileHandle: fileHandle)),
                    bucket: bucket,
                    key: key
                )
            )
        } catch {
            if let mapped = error as? StorageError {
                throw mapped
            }
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
