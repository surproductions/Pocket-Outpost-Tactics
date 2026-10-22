import Foundation

public enum BattlePhase: String, Codable, Sendable {
    case player
    case enemy
    case victory
    case defeat
}

/// Everything that happens in a battle, reported to the presentation layer so it can animate.
public enum BattleEvent: Equatable, Sendable {
    case moved(unitID: Int, path: [GridPoint])
    case attacked(attackerID: Int, target: GridPoint, damage: Int, ability: AbilityKind?)
    case unitDefeated(unitID: Int)
    case structureDamaged(at: GridPoint, damage: Int)
    case structureDestroyed(at: GridPoint)
    case healed(target: GridPoint, amount: Int)
    case barricadeBuilt(at: GridPoint)
    case statusApplied(unitID: Int, effect: StatusEffect)
    case dashed(unitID: Int)
    case reinforcementsArrived(unitIDs: [Int])
    case phaseChanged(BattlePhase)
}

/// Bonuses that come from the player's outpost and squad levels.
public struct SquadModifiers: Codable, Hashable, Sendable {
    public var rangedAttackBonus: Int
    public var bonusMaxHP: Int
    public var engineerBonus: Int

    public init(rangedAttackBonus: Int = 0, bonusMaxHP: Int = 0, engineerBonus: Int = 0) {
        self.rangedAttackBonus = rangedAttackBonus
        self.bonusMaxHP = bonusMaxHP
        self.engineerBonus = engineerBonus
    }

    public static let none = SquadModifiers()
}

public struct SquadMember: Codable, Hashable, Sendable {
    public var kind: UnitClass
    public var level: Int

    public init(kind: UnitClass, level: Int) {
        self.kind = kind
        self.level = level
    }
}

public struct BattleState: Codable, Sendable {
    public var mission: MissionDefinition
    public var width: Int
    public var height: Int
    public var terrain: [Terrain]
    public var structures: [GridPoint: Structure]
    public var units: [BattleUnit]
    public var round: Int = 1
    public var phase: BattlePhase = .player
    public var pendingReinforcements: [Reinforcement]
    public var modifiers: SquadModifiers
    public var nextUnitID: Int
    public var playerUnitsLost = 0

    // MARK: Setup

    public init(mission: MissionDefinition, squad: [SquadMember], modifiers: SquadModifiers = .none) {
        let layout = mission.parse()
        self.mission = mission
        self.width = mission.width
        self.height = mission.height
        self.terrain = layout.terrain
        self.structures = layout.structures
        self.modifiers = modifiers
        self.pendingReinforcements = mission.reinforcements
        var units: [BattleUnit] = []
        var id = 1
        for (member, slot) in zip(squad, layout.deploySlots) {
            let stats = Progression.stats(for: member.kind, level: member.level, modifiers: modifiers)
            units.append(BattleUnit(id: id, kind: member.kind, position: slot, stats: stats, level: member.level))
            id += 1
        }
        for (kind, p) in layout.enemies {
            let level = 1 + mission.enemyBonusLevel
            let stats = Progression.enemyStats(for: kind, level: level)
            units.append(BattleUnit(id: id, kind: kind, position: p, stats: stats, level: level))
            id += 1
        }
        self.units = units
        self.nextUnitID = id
    }

    // MARK: Queries

    public func contains(_ p: GridPoint) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
    }

    public func terrain(at p: GridPoint) -> Terrain {
        contains(p) ? terrain[p.y * width + p.x] : .rock
    }

    public func unit(id: Int) -> BattleUnit? {
        units.first { $0.id == id && $0.isAlive }
    }

    public func unit(at p: GridPoint) -> BattleUnit? {
        units.first { $0.position == p && $0.isAlive }
    }

    public func units(of faction: Faction) -> [BattleUnit] {
        units.filter { $0.faction == faction && $0.isAlive }
    }

    public var gatePosition: GridPoint? {
        structures.first { $0.value.kind == .gate }?.key
    }

    public var gate: Structure? {
        structures.values.first { $0.kind == .gate }
    }

    private func index(of id: Int) -> Int? {
        units.firstIndex { $0.id == id }
    }

    /// Tile can be stood on (ignoring units).
    public func isStandable(_ p: GridPoint) -> Bool {
        contains(p) && terrain(at: p).isPassable && structures[p] == nil
    }

    // MARK: Movement

    /// Movement costs to every tile the unit can reach this turn. Allies can be passed through,
    /// enemies cannot; destinations must be empty.
    public func reachableTiles(for unitID: Int) -> [GridPoint: Int] {
        guard let u = unit(id: unitID) else { return [:] }
        return reachable(from: u.position, faction: u.faction, budget: u.movePoints).costs
    }

    public func path(for unitID: Int, to destination: GridPoint) -> [GridPoint]? {
        guard let u = unit(id: unitID) else { return nil }
        let result = reachable(from: u.position, faction: u.faction, budget: u.movePoints)
        guard result.costs[destination] != nil else { return nil }
        var path = [destination]
        var current = destination
        while let prev = result.previous[current] {
            path.append(prev)
            current = prev
        }
        return path.reversed()
    }

    struct ReachResult {
        var costs: [GridPoint: Int]
        var previous: [GridPoint: GridPoint]
    }

    func reachable(from start: GridPoint, faction: Faction, budget: Int) -> ReachResult {
        var best: [GridPoint: Int] = [start: 0]
        var previous: [GridPoint: GridPoint] = [:]
        var frontier: [GridPoint] = [start]
        while !frontier.isEmpty {
            // Small grids: a simple ordered relaxation is fast and fully deterministic.
            frontier.sort { (best[$0]!, $0) < (best[$1]!, $1) }
            let current = frontier.removeFirst()
            let currentCost = best[current]!
            for n in current.neighbors where isStandable(n) {
                if let other = unit(at: n), other.faction != faction { continue }
                let cost = currentCost + terrain(at: n).moveCost
                if cost > budget { continue }
                if let known = best[n], known <= cost { continue }
                best[n] = cost
                previous[n] = current
                frontier.append(n)
            }
        }
        var costs: [GridPoint: Int] = [:]
        for (p, c) in best where p == start || unit(at: p) == nil {
            costs[p] = c
        }
        return ReachResult(costs: costs, previous: previous)
    }

    /// Every tile a unit could strike on its next turn (full movement plus attack range).
    public func threatTiles(for unitID: Int) -> Set<GridPoint> {
        guard let u = unit(id: unitID) else { return [] }
        let reach = reachable(from: u.position, faction: u.faction, budget: u.stats.move).costs.keys
        var tiles = Set<GridPoint>()
        for origin in reach {
            for y in 0..<height {
                for x in 0..<width {
                    let p = GridPoint(x, y)
                    let d = origin.distance(to: p)
                    if d >= u.stats.minRange && d <= u.stats.maxRange { tiles.insert(p) }
                }
            }
        }
        return tiles
    }

    /// Movement distance ignoring units' movement budgets (used by AI to head toward goals).
    public func travelDistances(from start: GridPoint, faction: Faction) -> [GridPoint: Int] {
        reachable(from: start, faction: faction, budget: Int.max / 4).costs.merging([start: 0]) { a, _ in a }
    }

    @discardableResult
    public mutating func move(unitID: Int, to destination: GridPoint) -> [BattleEvent] {
        guard phaseAllows(unitID), let i = index(of: unitID),
              let route = self.path(for: unitID, to: destination), destination != units[i].position,
              let cost = reachableTiles(for: unitID)[destination] else { return [] }
        units[i].position = destination
        units[i].movePoints -= cost
        return [.moved(unitID: unitID, path: route)]
    }

    private func phaseAllows(_ unitID: Int) -> Bool {
        guard let u = unit(id: unitID) else { return false }
        switch phase {
        case .player: return u.faction == .player
        case .enemy: return u.faction == .enemy
        default: return false
        }
    }

    // MARK: Targeting

    public func targets(for unitID: Int, from origin: GridPoint? = nil, ability: AbilityKind? = nil) -> [GridPoint] {
        guard let u = unit(id: unitID) else { return [] }
        let from = origin ?? u.position
        let (minR, maxR) = range(of: u, ability: ability)
        var result: [GridPoint] = []
        for y in 0..<height {
            for x in 0..<width {
                let p = GridPoint(x, y)
                let d = from.distance(to: p)
                guard d >= minR && d <= maxR else { continue }
                if ability == .fieldKit {
                    if isValidFieldKitTarget(p, for: u) { result.append(p) }
                    continue
                }
                if let other = unit(at: p), other.faction != u.faction {
                    result.append(p)
                } else if u.faction == .enemy, structures[p] != nil {
                    result.append(p)
                }
            }
        }
        return result
    }

    func range(of u: BattleUnit, ability: AbilityKind?) -> (Int, Int) {
        switch ability {
        case .precisionShot: return (2, 4)
        case .fieldKit, .smash: return (1, 1)
        default: return (u.stats.minRange, u.stats.maxRange)
        }
    }

    func isValidFieldKitTarget(_ p: GridPoint, for u: BattleUnit) -> Bool {
        if let other = unit(at: p) {
            return other.faction == u.faction && other.hp < other.stats.maxHP
        }
        if let s = structures[p] {
            return s.hp < s.maxHP
        }
        return isStandable(p)
    }

    // MARK: Damage

    /// Deterministic damage the attacker would deal to whatever is at `target`.
    public func damagePreview(attackerID: Int, from origin: GridPoint? = nil, target: GridPoint, ability: AbilityKind? = nil) -> Int {
        guard let attacker = unit(id: attackerID) else { return 0 }
        let from = origin ?? attacker.position
        var power = attacker.stats.attack
        if attacker.stats.isRanged || ability == .precisionShot,
           terrain(at: from) == .highGround, from.distance(to: target) > 1 {
            power += 1
        }
        if ability == .precisionShot { power += 2 }
        if ability == .smash { power += 3 }

        if let s = structures[target] {
            let structurePower = (attacker.kind == .brute || attacker.kind == .warlord) ? power * 2 : power
            return min(s.hp, max(1, structurePower))
        }
        guard let defender = unit(at: target) else { return 0 }

        if attacker.kind == .scout {
            let flanked = target.neighbors.contains { n in
                guard n != from, let ally = unit(at: n) else { return false }
                return ally.faction == attacker.faction && ally.id != attacker.id
            }
            if flanked { power += 2 }
        }

        var reduction = defender.effectiveDefense
        if ability != .precisionShot {
            reduction += coverBonus(at: target)
        }
        let guarded = target.neighbors.contains { n in
            guard let ally = unit(at: n) else { return false }
            return ally.faction == defender.faction && ally.id != defender.id && ally.has(.shielded)
        }
        if guarded { reduction += 1 }
        return max(1, power - reduction)
    }

    public func coverBonus(at p: GridPoint) -> Int {
        var cover = terrain(at: p).cover
        if p.neighbors.contains(where: { structures[$0]?.grantsAdjacentCover == true }) {
            cover += 1
        }
        return min(cover, 2)
    }

    // MARK: Actions

    @discardableResult
    public mutating func attack(unitID: Int, target: GridPoint) -> [BattleEvent] {
        guard phaseAllows(unitID), let attacker = unit(id: unitID), !attacker.hasActed,
              targets(for: unitID).contains(target) else { return [] }
        let damage = damagePreview(attackerID: unitID, target: target)
        var events: [BattleEvent] = [.attacked(attackerID: unitID, target: target, damage: damage, ability: nil)]
        events += applyDamage(damage, to: target)
        finishAction(unitID)
        events += checkOutcome()
        return events
    }

    @discardableResult
    public mutating func useAbility(unitID: Int, target: GridPoint? = nil) -> [BattleEvent] {
        guard phaseAllows(unitID), let u = unit(id: unitID), u.canUseAbility,
              let ability = u.kind.ability, let i = index(of: unitID) else { return [] }
        var events: [BattleEvent] = []
        switch ability {
        case .shieldWall:
            units[i].statuses.append(ActiveStatus(effect: .shielded, turnsRemaining: 1))
            events.append(.statusApplied(unitID: unitID, effect: .shielded))
        case .dash:
            units[i].movePoints += 3
            units[i].dashed = true
            events.append(.dashed(unitID: unitID))
        case .precisionShot, .smash:
            guard let target, targets(for: unitID, ability: ability).contains(target) else { return [] }
            let damage = damagePreview(attackerID: unitID, target: target, ability: ability)
            events.append(.attacked(attackerID: unitID, target: target, damage: damage, ability: ability))
            events += applyDamage(damage, to: target)
        case .fieldKit:
            guard let target, targets(for: unitID, ability: .fieldKit).contains(target) else { return [] }
            let amount = 4 + modifiers.engineerBonus
            if let ally = unit(at: target), let j = index(of: ally.id) {
                let healed = min(amount, units[j].stats.maxHP - units[j].hp)
                units[j].hp += healed
                events.append(.healed(target: target, amount: healed))
            } else if var s = structures[target] {
                let repaired = min(amount, s.maxHP - s.hp)
                s.hp += repaired
                structures[target] = s
                events.append(.healed(target: target, amount: repaired))
            } else {
                structures[target] = Structure(kind: .barricade, hp: 6 + modifiers.engineerBonus * 2)
                events.append(.barricadeBuilt(at: target))
            }
        }
        units[i].abilityCooldown = ability.cooldown
        if ability.consumesAction { finishAction(unitID) }
        events += checkOutcome()
        return events
    }

    /// Ends a unit's activity for this turn without acting.
    public mutating func wait(unitID: Int) {
        guard let i = index(of: unitID) else { return }
        units[i].hasActed = true
        units[i].movePoints = 0
    }

    private mutating func finishAction(_ unitID: Int) {
        guard let i = index(of: unitID) else { return }
        units[i].hasActed = true
        if !units[i].dashed { units[i].movePoints = 0 }
    }

    private mutating func applyDamage(_ damage: Int, to target: GridPoint) -> [BattleEvent] {
        if var s = structures[target] {
            s.hp -= damage
            if s.hp <= 0 {
                // A destroyed gate stays on record (at 0 HP) so the defeat check can see it.
                if s.kind == .gate {
                    s.hp = 0
                    structures[target] = s
                } else {
                    structures[target] = nil
                }
                return [.structureDamaged(at: target, damage: damage), .structureDestroyed(at: target)]
            }
            structures[target] = s
            return [.structureDamaged(at: target, damage: damage)]
        }
        guard let defender = unit(at: target), let j = index(of: defender.id) else { return [] }
        units[j].hp = max(0, units[j].hp - damage)
        if units[j].hp == 0 {
            if units[j].faction == .player { playerUnitsLost += 1 }
            return [.unitDefeated(unitID: defender.id)]
        }
        return []
    }

    // MARK: Turn flow

    /// True when no player unit has anything meaningful left to do.
    public var playerTurnFinished: Bool {
        units(of: .player).allSatisfy { u in
            u.isExhausted || (u.hasActed && reachableTiles(for: u.id).count <= 1)
        }
    }

    /// Ends the player phase and prepares the enemy phase (including reinforcements).
    @discardableResult
    public mutating func endPlayerTurn() -> [BattleEvent] {
        guard phase == .player else { return [] }
        phase = .enemy
        var events: [BattleEvent] = [.phaseChanged(.enemy)]
        events += spawnReinforcements()
        startTurn(for: .enemy)
        return events
    }

    /// Ends the enemy phase, advances the round and checks round-based objectives.
    @discardableResult
    public mutating func endEnemyTurn() -> [BattleEvent] {
        guard phase == .enemy else { return [] }
        if case .defend(let rounds) = mission.objective, round >= rounds, (gate?.hp ?? 0) > 0 {
            phase = .victory
            return [.phaseChanged(.victory)]
        }
        round += 1
        phase = .player
        startTurn(for: .player)
        return [.phaseChanged(.player)]
    }

    private mutating func startTurn(for faction: Faction) {
        for i in units.indices where units[i].faction == faction && units[i].isAlive {
            units[i].movePoints = units[i].stats.move
            units[i].hasActed = false
            units[i].dashed = false
            units[i].abilityCooldown = max(0, units[i].abilityCooldown - 1)
            units[i].statuses = units[i].statuses.compactMap { s in
                var s = s
                s.turnsRemaining -= 1
                return s.turnsRemaining > 0 ? s : nil
            }
        }
    }

    private mutating func spawnReinforcements() -> [BattleEvent] {
        let due = pendingReinforcements.filter { $0.round <= round }
        guard !due.isEmpty else { return [] }
        pendingReinforcements.removeAll { $0.round <= round }
        var ids: [Int] = []
        for r in due {
            guard let spot = nearestFreeTile(to: r.position) else { continue }
            let level = 1 + mission.enemyBonusLevel
            let unit = BattleUnit(id: nextUnitID, kind: r.kind, position: spot,
                            stats: Progression.enemyStats(for: r.kind, level: level), level: level)
            units.append(unit)
            ids.append(nextUnitID)
            nextUnitID += 1
        }
        return ids.isEmpty ? [] : [.reinforcementsArrived(unitIDs: ids)]
    }

    func nearestFreeTile(to p: GridPoint) -> GridPoint? {
        var candidates: [GridPoint] = []
        for y in 0..<height { for x in 0..<width { candidates.append(GridPoint(x, y)) } }
        return candidates
            .filter { isStandable($0) && unit(at: $0) == nil }
            .min { ($0.distance(to: p), $0) < ($1.distance(to: p), $1) }
    }

    @discardableResult
    public mutating func checkOutcome() -> [BattleEvent] {
        guard phase == .player || phase == .enemy else { return [] }
        if units(of: .player).isEmpty {
            phase = .defeat
            return [.phaseChanged(.defeat)]
        }
        if case .defend = mission.objective, let g = gate, g.hp <= 0 {
            phase = .defeat
            return [.phaseChanged(.defeat)]
        }
        if units(of: .enemy).isEmpty && pendingReinforcements.isEmpty {
            phase = .victory
            return [.phaseChanged(.victory)]
        }
        return []
    }

    /// 1-3 stars: win, no unit lost, and finished within par rounds.
    public var stars: Int {
        guard phase == .victory else { return 0 }
        var s = 1
        if playerUnitsLost == 0 { s += 1 }
        if round <= mission.parRounds { s += 1 }
        return s
    }
}
