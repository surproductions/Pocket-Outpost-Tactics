import Foundation

/// SplitMix64: tiny, fast, and identical on every platform, so a seed always builds the same map.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int(next() % UInt64(range.count)) + range.lowerBound
    }

    public mutating func chance(_ p: Double) -> Bool {
        Double(next() % 10_000) / 10_000 < p
    }
}

/// Builds later-chapter missions and daily challenges from a seed. Every generated map is checked
/// for connectivity so all raiders can be reached.
public enum MapGenerator {
    public static let width = 7
    public static let height = 9

    public static func chapterMissions(chapter: Int, biome: Biome, names: [String]) -> [MissionDefinition] {
        names.enumerated().map { i, name in
            let objective: Objective = (i == 1 || i == 3) ? .defend(rounds: 5) : .eliminate
            let difficulty = (chapter - 1) * 2 + i / 2
            let base = 120 + chapter * 40
            return generate(
                id: "c\(chapter)m\(i + 1)", chapter: chapter, index: i + 1, title: name,
                biome: biome, objective: objective, difficulty: difficulty,
                seed: UInt64(chapter * 1000 + i * 37 + 11),
                reward: Reward(coins: 40 + chapter * 15 + i * 5, supplies: base + i * 10,
                               timber: 30 + chapter * 15 + i * 5, xp: 50 + chapter * 10),
                boss: i == names.count - 1)
        }
    }

    /// Today's challenge. The same date gives everyone the same battle.
    public static func dailyChallenge(dayNumber: Int, highestChapter: Int) -> MissionDefinition {
        let biomes = Biome.allCases.prefix(max(1, min(highestChapter, Biome.allCases.count)))
        let biome = Array(biomes)[dayNumber % biomes.count]
        let objective: Objective = dayNumber % 2 == 0 ? .eliminate : .defend(rounds: 5)
        return generate(
            id: "daily-\(dayNumber)", chapter: 0, index: 0, title: "Daily Skirmish",
            biome: biome, objective: objective, difficulty: max(0, highestChapter - 1) * 2 + 1,
            seed: UInt64(dayNumber) &* 7919,
            reward: Reward(coins: 60, supplies: 60, timber: 20, xp: 40), boss: false)
    }

    public static func generate(id: String, chapter: Int, index: Int, title: String, biome: Biome,
                                objective: Objective, difficulty: Int, seed: UInt64, reward: Reward,
                                boss: Bool) -> MissionDefinition {
        var rows: [String] = []
        for attempt in 0...40 {
            var rng = SeededRandom(seed: seed &+ UInt64(attempt) &* 104_729)
            rows = layout(biome: biome, objective: objective, difficulty: difficulty, boss: boss, rng: &rng)
            if isConnected(rows) { break }
        }
        var reinforcements: [Reinforcement] = []
        if case .defend = objective {
            reinforcements = [
                Reinforcement(round: 2, kind: .raider, position: GridPoint(1, 0)),
                Reinforcement(round: 3, kind: difficulty > 3 ? .brute : .archer, position: GridPoint(5, 0)),
            ]
        }
        let enemyCount = rows.joined().filter { "rabw".contains($0) }.count
        return MissionDefinition(
            id: id, chapter: chapter, index: index, title: title,
            briefing: briefing(for: biome, objective: objective, boss: boss),
            biome: biome, objective: objective, rows: rows, reinforcements: reinforcements,
            reward: reward, parRounds: objective == .eliminate ? 4 + enemyCount : 5,
            enemyBonusLevel: difficulty / 2)
    }

    static func briefing(for biome: Biome, objective: Objective, boss: Bool) -> String {
        let place: String
        switch biome {
        case .forest: place = "in the deep woods"
        case .canyon: place = "among the canyon mesas"
        case .snow: place = "on the frozen pass"
        case .ruins: place = "amid the smouldering ruins"
        }
        if boss { return "A warlord leads the raiders \(place). Break their command and the region is yours." }
        switch objective {
        case .eliminate: return "A raider warband has made camp \(place). Drive them out."
        case .defend: return "Raiders are closing on a forward camp \(place). Keep the gate standing."
        }
    }

    static func layout(biome: Biome, objective: Objective, difficulty: Int, boss: Bool,
                       rng: inout SeededRandom) -> [String] {
        var grid = Array(repeating: Array(repeating: Character("."), count: width), count: height)
        let feature: Character
        let secondary: Character
        switch biome {
        case .forest: feature = "F"; secondary = "R"
        case .canyon: feature = "H"; secondary = "R"
        case .snow: feature = "S"; secondary = "W"
        case .ruins: feature = "U"; secondary = "R"
        }
        // Scatter features in the middle band (rows 2-5) with left/right mirroring for fairness.
        for y in 2...5 {
            for x in 0...(width / 2) where rng.chance(0.28) {
                let ch: Character = rng.chance(0.3) ? secondary : feature
                grid[y][x] = ch
                grid[y][width - 1 - x] = ch
            }
        }
        // Always leave a central lane.
        for y in 0..<height where grid[y][3] == "R" || grid[y][3] == "W" { grid[y][3] = "," }

        let isDefend: Bool
        if case .defend = objective { isDefend = true } else { isDefend = false }
        if isDefend {
            grid[8] = Array("R..G..R")
            grid[6][1] = "B"; grid[6][5] = "B"
            for (i, x) in [3, 1, 5, 3].enumerated() {
                let y = i == 3 ? 5 : 7
                grid[y][x] = Character(String(i + 1))
            }
        } else {
            grid[6] = Array(".......")
            grid[7] = Array(".1.2.3.")
            grid[8] = Array("...4...")
        }

        // Enemies in the top rows, budget grows with difficulty.
        var budget = 6 + difficulty * 2
        var spots: [GridPoint] = []
        for y in 0...1 { for x in 0..<width { spots.append(GridPoint(x, y)) } }
        var order: [GridPoint] = []
        while !spots.isEmpty {
            order.append(spots.remove(at: rng.int(0...(spots.count - 1))))
        }
        if boss, let p = order.first {
            grid[p.y][p.x] = "w"
            budget -= 7
            order.removeFirst()
        }
        for p in order where budget > 0 {
            let roll = rng.int(0...9)
            let pick: (Character, Int) = roll < 4 ? ("r", 2) : (roll < 7 ? ("a", 2) : ("b", 4))
            let ch = pick.0, cost = pick.1
            if difficulty < 2 && ch == "b" { continue }
            guard cost <= budget + 1 else { continue }
            grid[p.y][p.x] = ch
            budget -= cost
        }
        return grid.map { String($0) }
    }

    /// Every enemy and gate must be reachable from the squad's deployment area.
    public static func isConnected(_ rows: [String]) -> Bool {
        let grid = rows.map(Array.init)
        let h = grid.count, w = grid.first?.count ?? 0
        func passable(_ p: GridPoint) -> Bool {
            guard p.x >= 0, p.y >= 0, p.x < w, p.y < h else { return false }
            return !"RWBG".contains(grid[p.y][p.x])
        }
        var start: GridPoint?
        var required: [GridPoint] = []
        for y in 0..<h {
            for x in 0..<w {
                let c = grid[y][x]
                if c == "1" { start = GridPoint(x, y) }
                if "rabw1234".contains(c) { required.append(GridPoint(x, y)) }
            }
        }
        guard let s = start else { return false }
        var seen: Set<GridPoint> = [s]
        var queue = [s]
        while let p = queue.popLast() {
            for n in p.neighbors where passable(n) && !seen.contains(n) {
                seen.insert(n)
                queue.append(n)
            }
        }
        return required.allSatisfy { seen.contains($0) }
    }
}
