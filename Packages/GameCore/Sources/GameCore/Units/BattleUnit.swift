import Foundation

public enum StatusEffect: String, Codable, Sendable {
    /// Guardian Shield Wall: +2 defense and adjacent allies take 1 less damage.
    case shielded
}

public struct ActiveStatus: Codable, Hashable, Sendable {
    public var effect: StatusEffect
    /// Number of the owner's turns the effect still lasts (ticks down at the start of the owner's turn).
    public var turnsRemaining: Int
}

public struct BattleUnit: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var kind: UnitClass
    public var faction: Faction
    public var position: GridPoint
    public var stats: UnitStats
    public var hp: Int
    public var level: Int

    /// Movement left this turn. Moving can be split across several steps.
    public var movePoints: Int
    public var hasActed = false
    /// Scout Dash: remaining movement is kept after attacking.
    public var dashed = false
    public var abilityCooldown = 0
    public var statuses: [ActiveStatus] = []

    public init(id: Int, kind: UnitClass, position: GridPoint, stats: UnitStats? = nil, level: Int = 1) {
        self.id = id
        self.kind = kind
        self.faction = kind.faction
        self.position = position
        let s = stats ?? kind.baseStats
        self.stats = s
        self.hp = s.maxHP
        self.level = level
        self.movePoints = s.move
    }

    public var isAlive: Bool { hp > 0 }

    public func has(_ effect: StatusEffect) -> Bool {
        statuses.contains { $0.effect == effect }
    }

    public var effectiveDefense: Int {
        stats.defense + (has(.shielded) ? 2 : 0)
    }

    public var isExhausted: Bool { hasActed && movePoints == 0 }

    public var canUseAbility: Bool { kind.ability != nil && abilityCooldown == 0 && !hasActed }
}
