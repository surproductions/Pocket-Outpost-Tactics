import Foundation

/// Data-driven squad growth. Each level adds survivability first, damage second.
public enum Progression {
    public static let maxLevel = 5
    /// Total XP needed to reach each level (index 0 = level 1).
    public static let xpThresholds = [0, 40, 110, 220, 380]

    public static func level(forXP xp: Int) -> Int {
        var level = 1
        for (i, threshold) in xpThresholds.enumerated() where xp >= threshold {
            level = i + 1
        }
        return min(level, maxLevel)
    }

    /// XP still needed for the next level, or nil at max level.
    public static func xpToNext(xp: Int) -> Int? {
        let lvl = level(forXP: xp)
        guard lvl < maxLevel else { return nil }
        return xpThresholds[lvl] - xp
    }

    public static func stats(for kind: UnitClass, level: Int, modifiers: SquadModifiers) -> UnitStats {
        var s = kind.baseStats
        let bonusLevels = max(0, level - 1)
        s.maxHP += bonusLevels * 2 + modifiers.bonusMaxHP
        s.attack += level >= 4 ? 2 : (level >= 2 ? 1 : 0)
        s.defense += level >= 3 ? 1 : 0
        if s.isRanged { s.attack += modifiers.rangedAttackBonus }
        return s
    }

    public static func enemyStats(for kind: UnitClass, level: Int) -> UnitStats {
        var s = kind.baseStats
        let bonus = max(0, level - 1)
        s.maxHP += bonus * 2
        s.attack += bonus / 2
        s.defense += bonus / 3
        return s
    }

    /// One-line summary of what the next level grants, for the squad screen.
    public static func nextLevelPerk(for level: Int) -> String? {
        switch level {
        case 1: return "+2 HP, +1 attack"
        case 2: return "+2 HP, +1 defense"
        case 3: return "+2 HP, +1 attack"
        case 4: return "+2 HP"
        default: return nil
        }
    }
}
