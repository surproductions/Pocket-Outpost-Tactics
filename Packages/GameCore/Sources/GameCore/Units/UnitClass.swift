import Foundation

public enum Faction: String, Codable, Sendable {
    case player
    case enemy
}

/// Base numbers for each unit type. All combat is deterministic: damage = attack - defense - cover
/// (minimum 1), plus clearly listed bonuses.
public struct UnitStats: Codable, Hashable, Sendable {
    public var maxHP: Int
    public var attack: Int
    public var defense: Int
    public var move: Int
    public var minRange: Int
    public var maxRange: Int

    public init(maxHP: Int, attack: Int, defense: Int, move: Int, minRange: Int, maxRange: Int) {
        self.maxHP = maxHP
        self.attack = attack
        self.defense = defense
        self.move = move
        self.minRange = minRange
        self.maxRange = maxRange
    }

    public var isRanged: Bool { maxRange > 1 }
}

public enum UnitClass: String, Codable, CaseIterable, Sendable {
    // Player squad
    case guardian
    case ranger
    case scout
    case engineer
    // Enemies
    case raider
    case archer
    case brute
    case warlord

    public static let playerClasses: [UnitClass] = [.guardian, .ranger, .scout, .engineer]
    public static let enemyClasses: [UnitClass] = [.raider, .archer, .brute, .warlord]

    public var faction: Faction {
        switch self {
        case .guardian, .ranger, .scout, .engineer: return .player
        case .raider, .archer, .brute, .warlord: return .enemy
        }
    }

    public var baseStats: UnitStats {
        switch self {
        case .guardian: return UnitStats(maxHP: 16, attack: 5, defense: 2, move: 3, minRange: 1, maxRange: 1)
        case .ranger:   return UnitStats(maxHP: 10, attack: 5, defense: 0, move: 3, minRange: 2, maxRange: 3)
        case .scout:    return UnitStats(maxHP: 11, attack: 4, defense: 1, move: 5, minRange: 1, maxRange: 1)
        case .engineer: return UnitStats(maxHP: 12, attack: 3, defense: 1, move: 3, minRange: 1, maxRange: 2)
        case .raider:   return UnitStats(maxHP: 8, attack: 4, defense: 0, move: 4, minRange: 1, maxRange: 1)
        case .archer:   return UnitStats(maxHP: 7, attack: 4, defense: 0, move: 3, minRange: 2, maxRange: 3)
        case .brute:    return UnitStats(maxHP: 15, attack: 6, defense: 2, move: 2, minRange: 1, maxRange: 1)
        case .warlord:  return UnitStats(maxHP: 24, attack: 6, defense: 2, move: 3, minRange: 1, maxRange: 1)
        }
    }

    public var ability: AbilityKind? {
        switch self {
        case .guardian: return .shieldWall
        case .ranger: return .precisionShot
        case .scout: return .dash
        case .engineer: return .fieldKit
        case .brute, .warlord: return .smash
        case .raider, .archer: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .guardian: return "Guardian"
        case .ranger: return "Ranger"
        case .scout: return "Scout"
        case .engineer: return "Engineer"
        case .raider: return "Raider"
        case .archer: return "Raider Archer"
        case .brute: return "Heavy Brute"
        case .warlord: return "Thornjaw, Raider Warlord"
        }
    }

    public var role: String {
        switch self {
        case .guardian: return "Frontliner. Tough, protects nearby allies."
        case .ranger: return "Marksman. Strikes from 2-3 tiles away, fragile up close."
        case .scout: return "Skirmisher. Moves far and hits harder when flanking."
        case .engineer: return "Support. Builds cover and repairs allies and walls."
        case .raider: return "Fast melee attacker that hunts weak targets."
        case .archer: return "Ranged attacker that keeps its distance."
        case .brute: return "Slow and heavily armoured. Smashes barricades."
        case .warlord: return "Leader of the raiders. Hits hard and smashes defenses."
        }
    }

    /// Passive rule reminders shown in the unit panel.
    public var passiveText: String? {
        switch self {
        case .scout: return "Flank: +2 damage if another ally is next to the target."
        case .ranger: return "Can't attack adjacent enemies. +1 damage from high ground."
        case .archer: return "Can't attack adjacent targets. +1 damage from high ground."
        case .brute, .warlord: return "Deals double damage to barricades and the gate."
        default: return nil
        }
    }
}
