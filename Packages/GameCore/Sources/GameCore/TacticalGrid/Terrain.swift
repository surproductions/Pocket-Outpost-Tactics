import Foundation

/// Ground types. Combat is deterministic, so every terrain effect is a flat, visible number.
public enum Terrain: String, Codable, CaseIterable, Sendable {
    case grass
    case path
    case forest      // cover +1, costs 2 movement
    case rock        // impassable
    case water       // impassable
    case highGround  // ranged units standing here gain +1 damage
    case snow        // costs 2 movement
    case ruins       // cover +1

    public var isPassable: Bool {
        switch self {
        case .rock, .water: return false
        default: return true
        }
    }

    public var moveCost: Int {
        switch self {
        case .forest, .snow: return 2
        default: return 1
        }
    }

    /// Damage reduction granted to a unit standing on this tile.
    public var cover: Int {
        switch self {
        case .forest, .ruins: return 1
        default: return 0
        }
    }

    public var displayName: String {
        switch self {
        case .grass: return "Meadow"
        case .path: return "Trail"
        case .forest: return "Forest"
        case .rock: return "Boulder"
        case .water: return "Water"
        case .highGround: return "High Ground"
        case .snow: return "Deep Snow"
        case .ruins: return "Ruins"
        }
    }

    public var rulesText: String {
        switch self {
        case .grass, .path: return "Open ground."
        case .forest: return "Cover: -1 damage taken. Costs 2 movement."
        case .rock, .water: return "Impassable."
        case .highGround: return "Ranged attacks from here deal +1 damage."
        case .snow: return "Costs 2 movement."
        case .ruins: return "Cover: -1 damage taken."
        }
    }
}

/// Things that sit on a tile and can be damaged: barricades and the outpost gate.
public struct Structure: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case barricade
        case gate
    }

    public var kind: Kind
    public var hp: Int
    public var maxHP: Int

    public init(kind: Kind, hp: Int) {
        self.kind = kind
        self.hp = hp
        self.maxHP = hp
    }

    /// Barricades block movement. The gate also blocks movement.
    public var blocksMovement: Bool { true }

    /// Units adjacent to a barricade take less ranged damage from the far side; simplified to
    /// "a barricade grants cover to units directly next to it".
    public var grantsAdjacentCover: Bool { kind == .barricade }
}
