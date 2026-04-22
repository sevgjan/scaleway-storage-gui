import Foundation
import Security

protocol KeychainServicing {
    func saveSecret(_ secret: String) throws -> String
    func readSecret(for key: String) throws -> String
    func updateSecret(for key: String, to secret: String) throws
    func deleteSecret(for key: String) throws
}

final class KeychainService: KeychainServicing {
    private let service = "com.scaleway.gui.credentials"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
    }

    func saveSecret(_ secret: String) throws -> String {
        let key = UUID().uuidString
        var attrs = baseQuery
        attrs[kSecAttrAccount as String] = key
        attrs[kSecValueData as String] = Data(secret.utf8)
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attrs[kSecAttrSynchronizable as String] = false

        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status)
        }

        return key
    }

    func readSecret(for key: String) throws -> String {
        var query = baseQuery
        query[kSecAttrAccount as String] = key
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

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

    func updateSecret(for key: String, to secret: String) throws {
        var query = baseQuery
        query[kSecAttrAccount as String] = key

        let updates: [String: Any] = [
            kSecValueData as String: Data(secret.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
        ]

        let status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if status == errSecItemNotFound {
            _ = try saveSecret(secret)
            return
        }
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status)
        }
    }

    func deleteSecret(for key: String) throws {
        var query = baseQuery
        query[kSecAttrAccount as String] = key

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
