import Foundation

@MainActor
protocol StorageClient {
    func listBuckets() async throws -> [BucketItem]
    func listObjects(bucket: String, prefix: String?, delimiter: String?) async throws -> [ObjectItem]
    func downloadObject(bucket: String, key: String, to destinationURL: URL) async throws
    func uploadObject(bucket: String, key: String, from sourceURL: URL) async throws
}
