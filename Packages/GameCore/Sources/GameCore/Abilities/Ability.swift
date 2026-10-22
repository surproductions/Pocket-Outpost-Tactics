import Foundation

public enum AbilityKind: String, Codable, Sendable {
    case shieldWall
    case precisionShot
    case dash
    case fieldKit
    case smash

    public var displayName: String {
        switch self {
        case .shieldWall: return "Shield Wall"
        case .precisionShot: return "Precision Shot"
        case .dash: return "Dash"
        case .fieldKit: return "Field Kit"
        case .smash: return "Smash"
        }
    }

    public var description: String {
        switch self {
        case .shieldWall:
            return "Until your next turn: +2 defense, and adjacent allies take 1 less damage."
        case .precisionShot:
            return "A shot at range 2-4 that ignores cover and deals +2 damage."
        case .dash:
            return "Gain 3 extra movement this turn and keep any leftover movement after attacking."
        case .fieldKit:
            return "Adjacent tile: build a barricade on empty ground, or repair an ally or structure."
        case .smash:
            return "A crushing blow: +3 damage to an adjacent target."
        }
    }

    public var cooldown: Int {
        switch self {
        case .shieldWall: return 3
        case .precisionShot: return 3
        case .dash: return 3
        case .fieldKit: return 2
        case .smash: return 3
        }
    }

    /// Whether the ability needs a target tile (otherwise it is used on the caster).
    public var needsTarget: Bool {
        switch self {
        case .shieldWall, .dash: return false
        case .precisionShot, .fieldKit, .smash: return true
        }
    }

    /// Whether using the ability counts as the unit's action for the turn.
    public var consumesAction: Bool {
        switch self {
        case .dash: return false
        default: return true
        }
    }
}
