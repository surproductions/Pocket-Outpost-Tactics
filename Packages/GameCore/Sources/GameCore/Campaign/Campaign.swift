import Foundation

public struct Chapter: Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var biome: Biome
    public var tagline: String
    /// Command Center level needed to march here.
    public var requiredCommandLevel: Int
    public var missions: [MissionDefinition]
}

public enum Campaign {
    public static let chapters: [Chapter] = [
        Chapter(id: 1, name: "Greenwood Frontier", biome: .forest,
                tagline: "Raiders prowl the woods around your new outpost.",
                requiredCommandLevel: 1, missions: greenwood),
        Chapter(id: 2, name: "Dustfall Canyon", biome: .canyon,
                tagline: "Sun-baked mesas hide the raiders' supply lines.",
                requiredCommandLevel: 2,
                missions: MapGenerator.chapterMissions(chapter: 2, biome: .canyon, names: canyonNames)),
        Chapter(id: 3, name: "Frostwatch Pass", biome: .snow,
                tagline: "Hold the mountain pass through the long winter.",
                requiredCommandLevel: 3,
                missions: MapGenerator.chapterMissions(chapter: 3, biome: .snow, names: snowNames)),
        Chapter(id: 4, name: "Ember Ruins", biome: .ruins,
                tagline: "The warbands gather in the ruins of an ancient keep.",
                requiredCommandLevel: 4,
                missions: MapGenerator.chapterMissions(chapter: 4, biome: .ruins, names: ruinsNames)),
    ]

    public static var allMissions: [MissionDefinition] { chapters.flatMap(\.missions) }

    public static func mission(id: String) -> MissionDefinition? {
        allMissions.first { $0.id == id }
    }

    /// The mission after `id` in campaign order.
    public static func mission(after id: String) -> MissionDefinition? {
        let all = allMissions
        guard let i = all.firstIndex(where: { $0.id == id }), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    static let canyonNames = ["Sunscorch Trail", "The Dry Wells", "Mesa Lookout", "Rattlebone Gulch", "Dustfall Stronghold"]
    static let snowNames = ["Frozen Ford", "Whiteout Watch", "Avalanche Road", "Icefang Bridge", "The Frostwatch Gate"]
    static let ruinsNames = ["Ashen Steps", "Broken Colonnade", "Ember Vault", "The Sunken Hall", "Throne of Cinders"]

    // MARK: Chapter 1, handcrafted

    static let greenwood: [MissionDefinition] = [
        MissionDefinition(
            id: "c1m1", chapter: 1, index: 1, title: "First Watch",
            briefing: "A lone raider is sniffing around the outpost. Show them the frontier has a Guardian.",
            biome: .forest, objective: .eliminate,
            rows: [
                "R..F..R",
                ".......",
                "...r...",
                ".F...F.",
                ".......",
                "..,,,..",
                "...1...",
                ".......",
                "R.....R",
            ],
            reward: Reward(coins: 20, supplies: 60, timber: 10, xp: 30), parRounds: 4,
            unlocks: .ranger, tutorial: .basics, allowedClasses: [.guardian]),
        MissionDefinition(
            id: "c1m2", chapter: 1, index: 2, title: "Eyes in the Trees",
            briefing: "Two raiders approach. Keep your Ranger 2-3 tiles from danger and let the Guardian hold the front.",
            biome: .forest, objective: .eliminate,
            rows: [
                "F.....F",
                "..r..r.",
                ".......",
                "..F.F..",
                "...R...",
                ".......",
                "..1.2..",
                "...H...",
                "F.....F",
            ],
            reward: Reward(coins: 25, supplies: 60, timber: 15, xp: 30), parRounds: 5,
            tutorial: .ranged, allowedClasses: [.guardian, .ranger]),
        MissionDefinition(
            id: "c1m3", chapter: 1, index: 3, title: "Hold the Gate",
            briefing: "Raiders are making a run at the outpost gate. Survive 4 rounds and keep the gate standing.",
            biome: .forest, objective: .defend(rounds: 4),
            rows: [
                "..r..r.",
                ".......",
                "F..R..F",
                ".......",
                "..B.B..",
                "...1...",
                ".2.....",
                "F.....F",
                "R..G..R",
            ],
            reinforcements: [Reinforcement(round: 2, kind: .raider, position: GridPoint(3, 0))],
            reward: Reward(coins: 30, supplies: 70, timber: 20, xp: 35), parRounds: 4,
            unlocks: .scout, allowedClasses: [.guardian, .ranger]),
        MissionDefinition(
            id: "c1m4", chapter: 1, index: 4, title: "Brookside Ambush",
            briefing: "Raiders and an archer wait beyond the brook. Use the fords and let your Scout flank.",
            biome: .forest, objective: .eliminate,
            rows: [
                "F.a...F",
                "..r..r.",
                ".......",
                "WW,WW,W",
                ".......",
                ".F...F.",
                "..1.3..",
                "...2...",
                "F.....F",
            ],
            reward: Reward(coins: 30, supplies: 70, timber: 20, xp: 35), parRounds: 6),
        MissionDefinition(
            id: "c1m5", chapter: 1, index: 5, title: "Archer's Ridge",
            briefing: "Archers hold the ridge. High ground adds +1 ranged damage, for them and for you.",
            biome: .forest, objective: .eliminate,
            rows: [
                "..H.H..",
                "..a.a..",
                "r.....r",
                ".F.R.F.",
                ".......",
                "..F.F..",
                ".......",
                "..1.2..",
                "...3...",
            ],
            reward: Reward(coins: 35, supplies: 80, timber: 25, xp: 40), parRounds: 6,
            unlocks: .engineer),
        MissionDefinition(
            id: "c1m6", chapter: 1, index: 6, title: "The Long Night",
            briefing: "Waves of raiders strike after dark. Your Engineer can build barricades and patch the gate.",
            biome: .forest, objective: .defend(rounds: 5),
            rows: [
                ".r...r.",
                "...a...",
                "F.....F",
                "..R.R..",
                ".......",
                ".B...B.",
                "..1.4..",
                ".2...3.",
                "R..G..R",
            ],
            reinforcements: [
                Reinforcement(round: 2, kind: .raider, position: GridPoint(1, 0)),
                Reinforcement(round: 3, kind: .archer, position: GridPoint(5, 0)),
                Reinforcement(round: 4, kind: .raider, position: GridPoint(3, 0)),
            ],
            reward: Reward(coins: 40, supplies: 90, timber: 30, xp: 45), parRounds: 5),
        MissionDefinition(
            id: "c1m7", chapter: 1, index: 7, title: "Brute Force",
            briefing: "A Heavy Brute leads this band. It's slow: strike from range and don't let it reach your Ranger.",
            biome: .forest, objective: .eliminate,
            rows: [
                "F..b..F",
                ".r...r.",
                "...a...",
                ".F.R.F.",
                ".......",
                "..,,,..",
                ".1...2.",
                "..3.4..",
                "F.....F",
            ],
            reward: Reward(coins: 40, supplies: 90, timber: 30, xp: 45), parRounds: 7),
        MissionDefinition(
            id: "c1m8", chapter: 1, index: 8, title: "Burning Barricades",
            briefing: "Brutes smash barricades for double damage. Hold for 5 rounds.",
            biome: .forest, objective: .defend(rounds: 5),
            rows: [
                "..r.r..",
                "...b...",
                "F.....F",
                "..U.U..",
                ".......",
                "B..B..B",
                "..1.4..",
                ".2...3.",
                "R..G..R",
            ],
            reinforcements: [
                Reinforcement(round: 2, kind: .archer, position: GridPoint(1, 0)),
                Reinforcement(round: 3, kind: .raider, position: GridPoint(5, 0)),
            ],
            reward: Reward(coins: 45, supplies: 100, timber: 35, xp: 50), parRounds: 5),
        MissionDefinition(
            id: "c1m9", chapter: 1, index: 9, title: "Raider Camp",
            briefing: "Take the fight to the raider camp. Use the forest for cover and pick targets carefully.",
            biome: .forest, objective: .eliminate,
            rows: [
                "a.U.U..",
                "..rbr..",
                ".......",
                "F.....F",
                ".F.R.F.",
                ".......",
                "..,,,..",
                ".1.2.3.",
                "...4...",
            ],
            reward: Reward(coins: 50, supplies: 110, timber: 40, xp: 55), parRounds: 8),
        MissionDefinition(
            id: "c1m10", chapter: 1, index: 10, title: "Warlord of the Wood",
            briefing: "Thornjaw, the raider warlord, has come for your outpost. End this.",
            biome: .forest, objective: .eliminate,
            rows: [
                "F.a...F",
                "...w...",
                ".r...r.",
                "F.U.U.F",
                ".......",
                "..F.F..",
                ".......",
                ".1.2.3.",
                "...4...",
            ],
            reinforcements: [Reinforcement(round: 3, kind: .raider, position: GridPoint(3, 0))],
            reward: Reward(coins: 80, supplies: 150, timber: 60, xp: 70), parRounds: 9),
    ]
}
