import Foundation
import Security

protocol KeychainServicing {
    func saveSecret(_ secret: String) throws -> String
    func readSecret(for key: String) throws -> String
    func deleteSecret(for key: String) throws
}

final class KeychainService: KeychainServicing {
    private let service = "com.scaleway.gui.credentials"

    func saveSecret(_ secret: String) throws -> String {
        let key = UUID().uuidString
        let data = Data(secret.utf8)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status)
        }

        return key
    }

    func readSecret(for key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidEncoding
        }

        return secret
    }

    func deleteSecret(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case writeFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .writeFailed(let status):
            return "Keychain write failed (\(status))."
        case .readFailed(let status):
            return "Keychain read failed (\(status))."
        case .deleteFailed(let status):
            return "Keychain delete failed (\(status))."
        case .invalidEncoding:
            return "Invalid keychain data encoding."
        }
    }
}
