import Foundation

enum StorageError: Error {
    case invalidCredentials
    case endpointUnreachable
    case permissionDenied
    case objectNotFound
    case sdkError(String)
}

enum StorageErrorMapper {
    static func userMessage(for error: Error) -> String {
        if let storageError = error as? StorageError {
            switch storageError {
            case .invalidCredentials:
                return "Invalid credentials. Verify access key and secret key."
            case .endpointUnreachable:
                return "Endpoint unreachable. Check endpoint URL and network."
            case .permissionDenied:
                return "Permission denied for this operation."
            case .objectNotFound:
                return "Requested object was not found."
            case .sdkError(let message):
                return "Service error: \(message)"
            }
        }

        return "Unexpected error. Please retry."
    }
}
