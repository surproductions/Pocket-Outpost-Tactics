import Foundation

/// The whole save file. Plain Codable so it is easy to version, test and back up.
public struct PlayerProfile: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = PlayerProfile.currentVersion
    public var coins = 0
    public var supplies = 0
    public var timber = 0
    /// Building levels keyed by `BuildingKind.rawValue` (missing = level 1).
    public var buildings: [String: Int] = [:]
    public var unlockedClasses: [UnitClass] = [.guardian]
    /// XP per class keyed by `UnitClass.rawValue`.
    public var classXP: [String: Int] = [:]
    /// Best stars per mission id.
    public var missionStars: [String: Int] = [:]
    public var dailyChallengeClearedDay: Int?
    public var ownedCosmetics: [String] = []
    public var equippedBanner = "copper"
    public var settings = Settings()
    /// Tutorial beats already shown.
    public var seenTips: [String] = []
    /// Local-only play history used for D1/D7/D30 style retention stats on the device.
    public var playDays: [Int] = []
    public var firstPlayDay: Int?
    /// Simple lifetime counters (battles won, upgrades built...) kept on device only.
    public var counters: [String: Int] = [:]

    public struct Settings: Codable, Equatable, Sendable {
        public var soundOn = true
        public var hapticsOn = true
        public var reduceMotion = false
        public var fastEnemyTurns = false

        public init() {}
    }

    public init() {}

    // MARK: Squad

    public func xp(for kind: UnitClass) -> Int {
        classXP[kind.rawValue] ?? 0
    }

    public func level(for kind: UnitClass) -> Int {
        Progression.level(forXP: xp(for: kind))
    }

    public func squad(for mission: MissionDefinition) -> [SquadMember] {
        let classes = (mission.allowedClasses ?? UnitClass.playerClasses).filter { unlockedClasses.contains($0) }
        let slots = mission.parse().deploySlots.count
        return classes.prefix(slots).map { SquadMember(kind: $0, level: level(for: $0)) }
    }

    // MARK: Campaign

    public func isCompleted(_ missionID: String) -> Bool {
        (missionStars[missionID] ?? 0) > 0
    }

    public var totalStars: Int { missionStars.values.reduce(0, +) }

    public func isChapterUnlocked(_ chapter: Chapter) -> Bool {
        if chapter.id == 1 { return true }
        guard level(of: .commandCenter) >= chapter.requiredCommandLevel else { return false }
        guard let previous = Campaign.chapters.first(where: { $0.id == chapter.id - 1 }) else { return false }
        return previous.missions.allSatisfy { isCompleted($0.id) }
    }

    /// Previous chapter cleared but the Command Center is not high enough yet.
    public func chapterNeedsCommandUpgrade(_ chapter: Chapter) -> Bool {
        guard chapter.id > 1,
              let previous = Campaign.chapters.first(where: { $0.id == chapter.id - 1 }) else { return false }
        return previous.missions.allSatisfy { isCompleted($0.id) } && level(of: .commandCenter) < chapter.requiredCommandLevel
    }

    public func isMissionUnlocked(_ mission: MissionDefinition) -> Bool {
        guard let chapter = Campaign.chapters.first(where: { $0.id == mission.chapter }),
              isChapterUnlocked(chapter) else { return false }
        guard let i = chapter.missions.firstIndex(where: { $0.id == mission.id }) else { return false }
        return i == 0 || isCompleted(chapter.missions[i - 1].id)
    }

    /// The first unfinished mission, i.e. what "Continue" should open.
    public var nextMission: MissionDefinition? {
        Campaign.allMissions.first { isMissionUnlocked($0) && !isCompleted($0.id) }
    }

    public var highestUnlockedChapter: Int {
        Campaign.chapters.filter { isChapterUnlocked($0) }.map(\.id).max() ?? 1
    }

    // MARK: Rewards

    public struct VictorySummary: Equatable, Sendable {
        public var reward: Reward
        public var firstClear: Bool
        public var stars: Int
        public var unlocked: UnitClass?
        public var levelUps: [UnitClass]
    }

    /// Grants mission rewards. First clears pay in full, replays pay 40% (XP 50%).
    public mutating func applyVictory(mission: MissionDefinition, stars: Int, squad: [UnitClass],
                                      bonusMultiplier: Double = 1) -> VictorySummary {
        let firstClear = !isCompleted(mission.id) || mission.chapter == 0
        var reward = mission.reward
        if !firstClear {
            reward = Reward(coins: reward.coins * 2 / 5, supplies: reward.supplies * 2 / 5,
                            timber: reward.timber * 2 / 5, xp: reward.xp / 2)
        }
        reward.supplies = Int((Double(reward.supplies) * supplyMultiplier * bonusMultiplier).rounded())
        reward.coins = Int((Double(reward.coins) * bonusMultiplier).rounded())
        coins += reward.coins
        supplies += reward.supplies
        timber += reward.timber

        var levelUps: [UnitClass] = []
        for kind in squad {
            let before = level(for: kind)
            classXP[kind.rawValue] = xp(for: kind) + reward.xp
            if level(for: kind) > before { levelUps.append(kind) }
        }
        if mission.chapter > 0 {
            missionStars[mission.id] = max(missionStars[mission.id] ?? 0, stars)
        }
        var unlocked: UnitClass?
        if let u = mission.unlocks, !unlockedClasses.contains(u) {
            unlockedClasses.append(u)
            unlocked = u
        }
        return VictorySummary(reward: reward, firstClear: firstClear, stars: stars, unlocked: unlocked, levelUps: levelUps)
    }

    // MARK: Daily

    public static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        return Int((start.timeIntervalSince1970 + Double(calendar.timeZone.secondsFromGMT(for: start))) / 86_400)
    }

    public func canClaimDaily(day: Int) -> Bool {
        dailyChallengeClearedDay != day
    }

    public mutating func increment(_ counter: String, by amount: Int = 1) {
        counters[counter, default: 0] += amount
    }

    /// Whether the player came back 1, 7 and 30 days after their first session (local only).
    public var retentionMarks: (d1: Bool, d7: Bool, d30: Bool) {
        guard let first = firstPlayDay else { return (false, false, false) }
        let days = Set(playDays)
        return (days.contains(first + 1), days.contains(first + 7), days.contains(first + 30))
    }

    public mutating func recordPlay(day: Int) {
        if firstPlayDay == nil { firstPlayDay = day }
        if !playDays.contains(day) {
            playDays.append(day)
            if playDays.count > 120 { playDays.removeFirst(playDays.count - 120) }
        }
    }
}
