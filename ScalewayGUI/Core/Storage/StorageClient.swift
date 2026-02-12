import Foundation

@MainActor
protocol StorageClient {
    func listBuckets() async throws -> [BucketItem]
}
