import Foundation

public struct AIDecision: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case none
        case attack(GridPoint)
        case ability(AbilityKind, GridPoint?)
    }

    public var unitID: Int
    public var moveTo: GridPoint?
    public var action: Action
    public var score: Double
}

/// Lightweight utility AI. Every reachable tile is scored by the best action available from it
/// (damage, kills, objective pressure) minus the danger of standing there next turn. No randomness:
/// the same board always produces the same decision, so difficulty stays readable and fair.
public enum TacticalAI {

    public static func decide(for unitID: Int, in state: BattleState) -> AIDecision {
        guard let unit = state.unit(id: unitID) else {
            return AIDecision(unitID: unitID, moveTo: nil, action: .none, score: 0)
        }
        let threat = threatMap(against: unit, in: state)
        let reach = state.reachableTiles(for: unitID)
        let tiles = reach.keys.sorted()

        var best: AIDecision?
        for tile in tiles {
            var sim = state
            if let i = sim.units.firstIndex(where: { $0.id == unitID }) {
                sim.units[i].position = tile
            }
            let moved = sim.unit(id: unitID) ?? unit
            let positional = positionalScore(unit: moved, tile: tile, threat: threat, in: sim)
            var bestAction: (AIDecision.Action, Double) = (.none, 0)

            if !unit.hasActed {
                for target in sim.targets(for: unitID) {
                    let s = actionScore(attacker: moved, target: target, ability: nil, in: sim)
                    if s > bestAction.1 { bestAction = (.attack(target), s) }
                }
                if unit.canUseAbility, let ability = unit.kind.ability {
                    for (action, s) in abilityOptions(unit: moved, ability: ability, in: sim)
                    where s > bestAction.1 {
                        bestAction = (action, s)
                    }
                }
            }
            let total = bestAction.1 + positional
            let candidate = AIDecision(unitID: unitID, moveTo: tile == unit.position ? nil : tile,
                                       action: bestAction.0, score: total)
            if best == nil || total > best!.score + 0.0001 {
                best = candidate
            }
        }

        // Nothing worth attacking this turn: advance toward the most valuable goal instead.
        if let b = best, b.action == .none {
            return approach(unit: unit, reach: reach, threat: threat, in: state) ?? b
        }
        return best ?? AIDecision(unitID: unitID, moveTo: nil, action: .none, score: 0)
    }

    // MARK: Scoring

    static func actionScore(attacker: BattleUnit, target: GridPoint, ability: AbilityKind?, in state: BattleState) -> Double {
        let damage = state.damagePreview(attackerID: attacker.id, target: target, ability: ability)
        if let s = state.structures[target] {
            switch s.kind {
            case .gate:
                guard case .defend = state.mission.objective else { return 0 }
                return 30 + Double(damage) * 6
            case .barricade:
                return 2 + Double(damage) * (attacker.kind == .brute || attacker.kind == .warlord ? 2 : 0.5)
            }
        }
        guard let defender = state.unit(at: target) else { return 0 }
        var score = Double(damage) * 10
        if damage >= defender.hp { score += 50 }
        // Focus fire on wounded and fragile targets.
        score += Double(defender.stats.maxHP - defender.hp) * 1.5
        if defender.kind == .ranger || defender.kind == .engineer { score += 4 }
        return score
    }

    static func abilityOptions(unit: BattleUnit, ability: AbilityKind, in state: BattleState) -> [(AIDecision.Action, Double)] {
        switch ability {
        case .precisionShot, .smash:
            return state.targets(for: unit.id, ability: ability).map { t -> (AIDecision.Action, Double) in
                (AIDecision.Action.ability(ability, t), actionScore(attacker: unit, target: t, ability: ability, in: state) + 1)
            }
        case .shieldWall:
            let adjacentFoes = unit.position.neighbors.filter { state.unit(at: $0).map { $0.faction != unit.faction } ?? false }
            let adjacentAllies = unit.position.neighbors.filter { state.unit(at: $0).map { $0.faction == unit.faction } ?? false }
            guard !adjacentFoes.isEmpty else { return [] }
            return [(AIDecision.Action.ability(.shieldWall, nil), Double(adjacentFoes.count * 12 + adjacentAllies.count * 8))]
        case .fieldKit:
            return state.targets(for: unit.id, ability: .fieldKit).compactMap { t -> (AIDecision.Action, Double)? in
                if let ally = state.unit(at: t) {
                    let missing = ally.stats.maxHP - ally.hp
                    guard missing >= 4 else { return nil }
                    return (AIDecision.Action.ability(.fieldKit, t), Double(missing) * 7)
                }
                if let s = state.structures[t], s.kind == .gate, s.hp < s.maxHP {
                    return (AIDecision.Action.ability(.fieldKit, t), Double(s.maxHP - s.hp) * 4)
                }
                return nil
            }
        case .dash:
            return []
        }
    }

    static func positionalScore(unit: BattleUnit, tile: GridPoint, threat: [GridPoint: Int], in state: BattleState) -> Double {
        let danger = Double(threat[tile] ?? 0)
        let fragility = unit.hp <= unit.stats.maxHP / 2 ? 1.6 : 1.0
        var score = -danger * 1.2 * fragility
        score += Double(state.coverBonus(at: tile)) * 4
        if unit.stats.isRanged {
            let nearest = state.units(of: unit.faction == .player ? .enemy : .player)
                .map { $0.position.distance(to: tile) }.min() ?? 10
            if nearest >= 2 { score += 5 }
            if state.terrain(at: tile) == .highGround { score += 3 }
        }
        return score
    }

    /// Damage each tile could receive next turn from the opposing side.
    static func threatMap(against unit: BattleUnit, in state: BattleState) -> [GridPoint: Int] {
        var threat: [GridPoint: Int] = [:]
        let foes = state.units(of: unit.faction == .player ? .enemy : .player)
        for foe in foes {
            for p in state.threatTiles(for: foe.id) {
                threat[p, default: 0] += max(1, foe.stats.attack - unit.effectiveDefense)
            }
        }
        return threat
    }

    // MARK: Approach

    static func approach(unit: BattleUnit, reach: [GridPoint: Int], threat: [GridPoint: Int], in state: BattleState) -> AIDecision? {
        var goals: [GridPoint] = state.units(of: unit.faction == .player ? .enemy : .player).map(\.position)
        if unit.faction == .enemy, case .defend = state.mission.objective, let gate = state.gatePosition,
           unit.kind != .archer {
            goals = [gate]
        }
        guard !goals.isEmpty else { return nil }
        let field = distanceField(to: goals, in: state)
        let desired = unit.stats.isRanged ? unit.stats.minRange : 1
        var best: (GridPoint, Double)?
        for tile in reach.keys.sorted() {
            guard let d = field[tile] else { continue }
            let gap = Double(abs(d - desired))
            let score = -gap * 6 - Double(threat[tile] ?? 0) * 0.4 + Double(state.coverBonus(at: tile))
            if best == nil || score > best!.1 + 0.0001 { best = (tile, score) }
        }
        guard let (tile, score) = best else { return nil }
        return AIDecision(unitID: unit.id, moveTo: tile == unit.position ? nil : tile, action: .none, score: score)
    }

    /// Walking distance from every tile to the nearest goal. Structures can be "walked through" at a
    /// high cost so attackers still head toward a walled-in objective (and then break the wall).
    static func distanceField(to goals: [GridPoint], in state: BattleState) -> [GridPoint: Int] {
        var dist: [GridPoint: Int] = [:]
        var frontier: [GridPoint] = []
        for g in goals {
            dist[g] = 0
            frontier.append(g)
        }
        while !frontier.isEmpty {
            frontier.sort { (dist[$0]!, $0) < (dist[$1]!, $1) }
            let current = frontier.removeFirst()
            for n in current.neighbors where state.contains(n) && state.terrain(at: n).isPassable {
                let step = state.structures[n] != nil ? 4 : state.terrain(at: n).moveCost
                let cost = dist[current]! + step
                if let known = dist[n], known <= cost { continue }
                dist[n] = cost
                frontier.append(n)
            }
        }
        return dist
    }

    // MARK: Turn driver

    /// The next unit of the active faction that still needs orders, or nil when the phase is done.
    public static func nextUnit(in state: BattleState) -> Int? {
        let faction: Faction = state.phase == .enemy ? .enemy : .player
        let pending = state.units(of: faction).filter { !$0.hasActed }
        // Units that can already strike go first, so the AI doesn't body-block itself.
        return pending.sorted { a, b in
            let aCan = !state.targets(for: a.id).isEmpty
            let bCan = !state.targets(for: b.id).isEmpty
            if aCan != bCan { return aCan }
            return a.id < b.id
        }.first?.id
    }

    /// Applies a decision and returns the events produced.
    @discardableResult
    public static func execute(_ decision: AIDecision, in state: inout BattleState) -> [BattleEvent] {
        var events: [BattleEvent] = []
        if let destination = decision.moveTo {
            events += state.move(unitID: decision.unitID, to: destination)
        }
        switch decision.action {
        case .none:
            break
        case .attack(let target):
            events += state.attack(unitID: decision.unitID, target: target)
        case .ability(_, let target):
            events += state.useAbility(unitID: decision.unitID, target: target)
        }
        state.wait(unitID: decision.unitID)
        return events
    }

    /// Plays the whole active phase automatically (enemy turns, and player turns in simulations).
    @discardableResult
    public static func playPhase(_ state: inout BattleState) -> [BattleEvent] {
        var events: [BattleEvent] = []
        var guardCounter = 0
        while state.phase == .enemy || state.phase == .player, let id = nextUnit(in: state), guardCounter < 50 {
            guardCounter += 1
            events += execute(decide(for: id, in: state), in: &state)
        }
        if state.phase == .enemy {
            events += state.endEnemyTurn()
        } else if state.phase == .player {
            events += state.endPlayerTurn()
        }
        return events
    }

    /// Auto-plays a full battle with the AI controlling both sides. Used by tests to prove every
    /// mission is winnable and by the balancing tools.
    public static func simulate(_ state: inout BattleState, maxRounds: Int = 30) {
        while (state.phase == .player || state.phase == .enemy) && state.round <= maxRounds {
            playPhase(&state)
        }
    }
}
