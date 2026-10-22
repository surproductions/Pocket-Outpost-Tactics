import Foundation

public enum Biome: String, Codable, CaseIterable, Sendable {
    case forest
    case canyon
    case snow
    case ruins
}

public enum Objective: Codable, Hashable, Sendable {
    /// Defeat every raider, including any reinforcements.
    case eliminate
    /// Keep the outpost gate standing until the end of round `rounds` (or defeat every raider).
    case defend(rounds: Int)

    public var title: String {
        switch self {
        case .eliminate: return "Eliminate the Raiders"
        case .defend: return "Defend the Outpost"
        }
    }

    public var summary: String {
        switch self {
        case .eliminate:
            return "Defeat every raider on the field."
        case .defend(let rounds):
            return "Keep the gate standing for \(rounds) rounds, or defeat every raider."
        }
    }
}

public struct Reward: Codable, Hashable, Sendable {
    public var coins: Int
    public var supplies: Int
    public var timber: Int
    public var xp: Int

    public init(coins: Int = 0, supplies: Int = 0, timber: Int = 0, xp: Int = 0) {
        self.coins = coins
        self.supplies = supplies
        self.timber = timber
        self.xp = xp
    }

    public static let zero = Reward()

    public func scaled(_ factor: Double) -> Reward {
        Reward(coins: Int((Double(coins) * factor).rounded()),
               supplies: Int((Double(supplies) * factor).rounded()),
               timber: Int((Double(timber) * factor).rounded()),
               xp: Int((Double(xp) * factor).rounded()))
    }

    public static func + (lhs: Reward, rhs: Reward) -> Reward {
        Reward(coins: lhs.coins + rhs.coins, supplies: lhs.supplies + rhs.supplies,
               timber: lhs.timber + rhs.timber, xp: lhs.xp + rhs.xp)
    }
}

public struct Reinforcement: Codable, Hashable, Sendable {
    public var round: Int
    public var kind: UnitClass
    public var position: GridPoint

    public init(round: Int, kind: UnitClass, position: GridPoint) {
        self.round = round
        self.kind = kind
        self.position = position
    }
}

/// Tutorial beats shown during the onboarding missions.
public enum TutorialKind: String, Codable, Sendable {
    case basics        // select, move, attack
    case ranged        // ranger positioning
}

/// A handcrafted or generated battle.
///
/// Map legend (one character per tile, rows top to bottom):
/// `.` meadow  `,` trail  `F` forest  `R` boulder  `W` water  `H` high ground  `S` snow  `U` ruins
/// `B` barricade  `G` outpost gate  `1`-`4` squad deployment slots
/// `r` raider  `a` archer  `b` brute  `w` warlord (enemies stand on meadow)
public struct MissionDefinition: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var chapter: Int
    public var index: Int
    public var title: String
    public var briefing: String
    public var biome: Biome
    public var objective: Objective
    public var rows: [String]
    public var reinforcements: [Reinforcement]
    public var reward: Reward
    /// Rounds to finish within for the third star.
    public var parRounds: Int
    public var unlocks: UnitClass?
    public var tutorial: TutorialKind?
    /// Squad members available. `nil` means everyone unlocked (up to the number of slots).
    public var allowedClasses: [UnitClass]?
    /// Extra levels added to every enemy (used by later chapters and daily challenges).
    public var enemyBonusLevel: Int

    public init(id: String, chapter: Int, index: Int, title: String, briefing: String, biome: Biome,
                objective: Objective, rows: [String], reinforcements: [Reinforcement] = [],
                reward: Reward, parRounds: Int, unlocks: UnitClass? = nil, tutorial: TutorialKind? = nil,
                allowedClasses: [UnitClass]? = nil, enemyBonusLevel: Int = 0) {
        self.id = id
        self.chapter = chapter
        self.index = index
        self.title = title
        self.briefing = briefing
        self.biome = biome
        self.objective = objective
        self.rows = rows
        self.reinforcements = reinforcements
        self.reward = reward
        self.parRounds = parRounds
        self.unlocks = unlocks
        self.tutorial = tutorial
        self.allowedClasses = allowedClasses
        self.enemyBonusLevel = enemyBonusLevel
    }

    public var width: Int { rows.first?.count ?? 0 }
    public var height: Int { rows.count }

    /// Parsed layout of the map.
    public struct Layout: Sendable {
        public var terrain: [Terrain]
        public var structures: [GridPoint: Structure]
        public var deploySlots: [GridPoint]
        public var enemies: [(UnitClass, GridPoint)]
    }

    public func parse() -> Layout {
        var terrain: [Terrain] = []
        var structures: [GridPoint: Structure] = [:]
        var slots: [(Int, GridPoint)] = []
        var enemies: [(UnitClass, GridPoint)] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                let p = GridPoint(x, y)
                switch ch {
                case ",": terrain.append(.path)
                case "F": terrain.append(.forest)
                case "R": terrain.append(.rock)
                case "W": terrain.append(.water)
                case "H": terrain.append(.highGround)
                case "S": terrain.append(.snow)
                case "U": terrain.append(.ruins)
                case "B":
                    terrain.append(.grass)
                    structures[p] = Structure(kind: .barricade, hp: 8)
                case "G":
                    terrain.append(.path)
                    structures[p] = Structure(kind: .gate, hp: 20)
                case "1", "2", "3", "4":
                    terrain.append(.grass)
                    slots.append((Int(String(ch)) ?? 9, p))
                case "r":
                    terrain.append(.grass); enemies.append((.raider, p))
                case "a":
                    terrain.append(.grass); enemies.append((.archer, p))
                case "b":
                    terrain.append(.grass); enemies.append((.brute, p))
                case "w":
                    terrain.append(.grass); enemies.append((.warlord, p))
                default:
                    terrain.append(.grass)
                }
            }
        }
        slots.sort { $0.0 < $1.0 }
        return Layout(terrain: terrain, structures: structures, deploySlots: slots.map { $0.1 }, enemies: enemies)
    }
}
