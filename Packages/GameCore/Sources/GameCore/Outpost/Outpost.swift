import Foundation

public struct Cost: Codable, Hashable, Sendable {
    public var supplies: Int
    public var timber: Int

    public init(supplies: Int, timber: Int) {
        self.supplies = supplies
        self.timber = timber
    }
}

public enum BuildingKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case commandCenter
    case watchtower
    case barracks
    case workshop
    case supplyDepot

    public var id: String { rawValue }

    public var maxLevel: Int {
        self == .commandCenter ? 4 : 3
    }

    public var displayName: String {
        switch self {
        case .commandCenter: return "Command Center"
        case .watchtower: return "Watchtower"
        case .barracks: return "Barracks"
        case .workshop: return "Workshop"
        case .supplyDepot: return "Supply Depot"
        }
    }

    public func levelName(_ level: Int) -> String {
        switch (self, level) {
        case (.commandCenter, 1): return "Command Tent"
        case (.commandCenter, _): return "Command Center"
        case (.watchtower, 1): return "Lookout Post"
        case (.watchtower, _): return "Watchtower"
        case (.barracks, 1): return "Bedroll Camp"
        case (.barracks, _): return "Barracks"
        case (.workshop, 1): return "Tool Bench"
        case (.workshop, _): return "Workshop"
        case (.supplyDepot, 1): return "Supply Cart"
        case (.supplyDepot, _): return "Supply Depot"
        }
    }

    /// Cost to go from `level - 1` to `level`. Nil when `level` is out of range.
    public func cost(toReach level: Int) -> Cost? {
        guard level >= 2 && level <= maxLevel else { return nil }
        let table: [Cost]
        switch self {
        case .commandCenter:
            table = [Cost(supplies: 250, timber: 80), Cost(supplies: 450, timber: 150), Cost(supplies: 700, timber: 250)]
        case .watchtower:
            table = [Cost(supplies: 60, timber: 0), Cost(supplies: 220, timber: 70)]
        case .barracks:
            table = [Cost(supplies: 90, timber: 20), Cost(supplies: 240, timber: 80)]
        case .workshop:
            table = [Cost(supplies: 80, timber: 25), Cost(supplies: 220, timber: 70)]
        case .supplyDepot:
            table = [Cost(supplies: 70, timber: 15), Cost(supplies: 200, timber: 60)]
        }
        return table[level - 2]
    }

    public func effect(at level: Int) -> String {
        let bonus = max(0, level - 1)
        switch self {
        case .commandCenter:
            let regions = ["Greenwood Frontier", "Dustfall Canyon", "Frostwatch Pass", "Ember Ruins"]
            return "Unlocks expeditions to \(regions[min(level, regions.count) - 1])."
        case .watchtower:
            return bonus == 0 ? "Ranged units: no bonus yet." : "Rangers and Engineers deal +\(bonus) damage."
        case .barracks:
            return bonus == 0 ? "Squad: no bonus yet." : "Every squad member gains +\(bonus * 2) max HP."
        case .workshop:
            return bonus == 0 ? "Field Kit: repairs 4, barricades have 6 HP." :
                "Field Kit: repairs \(4 + bonus), barricades have \(6 + bonus * 2) HP."
        case .supplyDepot:
            return bonus == 0 ? "Mission supplies: standard." : "Mission supplies +\(bonus * 25)%."
        }
    }
}

public extension PlayerProfile {
    func level(of building: BuildingKind) -> Int {
        buildings[building.rawValue] ?? 1
    }

    var squadModifiers: SquadModifiers {
        SquadModifiers(
            rangedAttackBonus: level(of: .watchtower) - 1,
            bonusMaxHP: (level(of: .barracks) - 1) * 2,
            engineerBonus: level(of: .workshop) - 1)
    }

    var supplyMultiplier: Double {
        1 + Double(level(of: .supplyDepot) - 1) * 0.25
    }

    func canAfford(_ cost: Cost) -> Bool {
        supplies >= cost.supplies && timber >= cost.timber
    }

    func upgradeCost(for building: BuildingKind) -> Cost? {
        building.cost(toReach: level(of: building) + 1)
    }

    /// Spends resources and raises the building one level. Returns false if not possible.
    @discardableResult
    mutating func upgrade(_ building: BuildingKind) -> Bool {
        guard let cost = upgradeCost(for: building), canAfford(cost) else { return false }
        supplies -= cost.supplies
        timber -= cost.timber
        buildings[building.rawValue] = level(of: building) + 1
        return true
    }
}
