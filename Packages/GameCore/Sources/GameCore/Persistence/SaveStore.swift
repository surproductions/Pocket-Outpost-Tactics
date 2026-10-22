import Foundation

/// Atomic JSON save files. The profile and any in-progress battle are stored separately so a
/// corrupt battle snapshot can never cost the player their outpost.
public struct SaveStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func defaultStore() -> SaveStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return SaveStore(directory: base.appendingPathComponent("PocketOutpostTactics", isDirectory: true))
    }

    var profileURL: URL { directory.appendingPathComponent("profile.json") }
    var battleURL: URL { directory.appendingPathComponent("battle.json") }

    public func loadProfile() -> PlayerProfile {
        guard let data = try? Data(contentsOf: profileURL),
              let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) else {
            return PlayerProfile()
        }
        return profile
    }

    public func save(_ profile: PlayerProfile) throws {
        try write(profile, to: profileURL)
    }

    public func loadBattle() -> BattleState? {
        guard let data = try? Data(contentsOf: battleURL) else { return nil }
        return try? JSONDecoder().decode(BattleState.self, from: data)
    }

    public func saveBattle(_ battle: BattleState?) throws {
        if let battle {
            try write(battle, to: battleURL)
        } else if FileManager.default.fileExists(atPath: battleURL.path) {
            try FileManager.default.removeItem(at: battleURL)
        }
    }

    public func reset() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }
}
