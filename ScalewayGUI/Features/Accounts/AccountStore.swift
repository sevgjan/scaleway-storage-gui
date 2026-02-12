import Foundation

final class AccountStore {
    private let defaults: UserDefaults
    private let key = "scaleway.accountProfiles.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> [AccountProfile] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([AccountProfile].self, from: data)
    }

    func upsert(_ profile: AccountProfile) throws {
        var profiles = try load()
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }

        let data = try JSONEncoder().encode(profiles)
        defaults.set(data, forKey: key)
    }

    func delete(id: UUID) throws {
        let filtered = try load().filter { $0.id != id }
        let data = try JSONEncoder().encode(filtered)
        defaults.set(data, forKey: key)
    }
}
