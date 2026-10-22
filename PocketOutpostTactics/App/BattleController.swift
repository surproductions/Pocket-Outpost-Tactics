import SwiftUI
import SpriteKit
import GameCore

/// Mediates between player input, the rules engine, the AI and the SpriteKit board.
@MainActor
final class BattleController: ObservableObject {
    enum Mode: Equatable {
        case idle
        case abilityTargeting
    }

    struct Outcome {
        var victory: Bool
        var summary: PlayerProfile.VictorySummary?
    }

    @Published private(set) var state: BattleState
    @Published var selectedID: Int?
    @Published var inspectedID: Int?
    @Published var inspectedTile: GridPoint?
    @Published var mode: Mode = .idle
    @Published var pendingTarget: GridPoint?
    @Published var banner: String?
    @Published private(set) var busy = false
    @Published var outcome: Outcome?
    @Published var paused = false

    let scene: BattleScene
    private weak var game: GameStore?

    init(state: BattleState, game: GameStore) {
        self.state = state
        self.game = game
        scene = BattleScene(size: CGSize(width: 390, height: 844))
        scene.reduceMotion = game.reduceMotion
        scene.fastEnemies = game.profile.settings.fastEnemyTurns
        scene.controller = self
        scene.setup(with: state)
        showBanner(state.round == 1 ? state.mission.objective.title : "Round \(state.round)")
    }

    // MARK: Derived

    var selectedUnit: BattleUnit? { selectedID.flatMap { state.unit(id: $0) } }
    var inspectedUnit: BattleUnit? { inspectedID.flatMap { state.unit(id: $0) } }

    var moveTiles: [GridPoint] {
        guard let u = selectedUnit, mode == .idle, u.movePoints > 0 else { return [] }
        return state.reachableTiles(for: u.id).keys.filter { $0 != u.position }
    }

    var attackTiles: [GridPoint] {
        guard let u = selectedUnit, mode == .idle, !u.hasActed else { return [] }
        return state.targets(for: u.id)
    }

    var abilityTiles: [GridPoint] {
        guard let u = selectedUnit, mode == .abilityTargeting, let ability = u.kind.ability else { return [] }
        return state.targets(for: u.id, ability: ability)
    }

    var pendingDamage: Int? {
        guard let u = selectedUnit, let t = pendingTarget else { return nil }
        return state.damagePreview(attackerID: u.id, target: t, ability: mode == .abilityTargeting ? u.kind.ability : nil)
    }

    var pendingIsLethal: Bool {
        guard let t = pendingTarget, let dmg = pendingDamage else { return false }
        if let target = state.unit(at: t) { return dmg >= target.hp }
        if let s = state.structures[t] { return dmg >= s.hp }
        return false
    }

    var objectiveStatus: String {
        switch state.mission.objective {
        case .eliminate:
            let left = state.units(of: .enemy).count + state.pendingReinforcements.count
            return "Raiders left: \(left)"
        case .defend(let rounds):
            let gateHP = state.gate?.hp ?? 0
            let remaining = max(0, rounds - state.round + 1)
            return "Gate \(gateHP) HP · \(remaining) round\(remaining == 1 ? "" : "s") to hold"
        }
    }

    var canEndTurn: Bool { state.phase == .player && !busy && outcome == nil }

    var allUnitsDone: Bool { state.playerTurnFinished }

    // MARK: Tutorial

    var tutorialHint: String? {
        guard state.phase == .player, !busy, outcome == nil else { return nil }
        switch state.mission.tutorial {
        case .basics:
            guard let g = state.units(of: .player).first else { return nil }
            if pendingTarget != nil { return "The number is the damage you'll deal. Tap the Raider again to strike!" }
            if selectedID == nil {
                return g.hasActed ? "Tap End Turn. The raider moves after you." : "Tap your Guardian to select them."
            }
            if !attackTiles.isEmpty { return "Red marks a foe in reach. Tap the Raider to preview your attack." }
            if g.movePoints > 0 { return "Blue tiles show where you can move. Tap one to march toward the Raider." }
            return "Out of moves. Tap End Turn and let the raider come to you."
        case .ranged:
            guard state.round <= 2 else { return nil }
            if let u = selectedUnit, u.kind == .ranger {
                return "Rangers shoot 2-3 tiles away but can't hit adjacent foes. The pale high-ground tile gives +1 damage."
            }
            return state.round == 1 ? "Select your Ranger and keep the Guardian between it and the raiders." : nil
        case nil:
            if state.round == 1, selectedID == nil, inspectedID == nil, state.mission.chapter == 1, state.mission.index <= 4 {
                return "Tip: tap an enemy to see how far it can strike next turn."
            }
            return nil
        }
    }

    // MARK: Input

    func handleTap(_ p: GridPoint) {
        guard state.phase == .player, !busy, outcome == nil, !paused else { return }

        if mode == .abilityTargeting {
            if abilityTiles.contains(p) {
                if pendingTarget == p { confirmAbility() } else { setPending(p) }
            } else {
                cancelAbility()
            }
            return
        }

        if let u = selectedUnit {
            if attackTiles.contains(p) {
                if pendingTarget == p { confirmAttack() } else { setPending(p) }
                return
            }
            if moveTiles.contains(p) {
                move(u, to: p)
                return
            }
        }

        if let unit = state.unit(at: p) {
            if unit.faction == .player {
                select(unit.id)
            } else {
                Feedback.tap()
                selectedID = nil
                pendingTarget = nil
                inspectedTile = nil
                inspectedID = unit.id
                refreshOverlays()
            }
            return
        }

        // Empty tile: show terrain info.
        Feedback.tap()
        selectedID = nil
        inspectedID = nil
        pendingTarget = nil
        inspectedTile = p
        refreshOverlays()
    }

    func select(_ id: Int) {
        Feedback.select()
        selectedID = id
        inspectedID = nil
        inspectedTile = nil
        pendingTarget = nil
        mode = .idle
        refreshOverlays()
    }

    func deselect() {
        selectedID = nil
        pendingTarget = nil
        mode = .idle
        refreshOverlays()
    }

    private func setPending(_ p: GridPoint) {
        Feedback.tap()
        pendingTarget = p
        refreshOverlays()
    }

    private func move(_ unit: BattleUnit, to p: GridPoint) {
        pendingTarget = nil
        let events = state.move(unitID: unit.id, to: p)
        guard !events.isEmpty else { return Feedback.error() }
        run(events) { [weak self] in
            guard let self else { return }
            // Auto-select a target if exactly one is now in reach (saves a tap; still needs confirm).
            self.refreshOverlays()
            self.afterPlayerAction()
        }
    }

    func confirmAttack() {
        guard let u = selectedUnit, let t = pendingTarget else { return }
        let events = state.attack(unitID: u.id, target: t)
        pendingTarget = nil
        guard !events.isEmpty else { return Feedback.error() }
        run(events) { [weak self] in self?.afterPlayerAction() }
    }

    func beginAbility() {
        guard let u = selectedUnit, u.canUseAbility, let ability = u.kind.ability else { return Feedback.error() }
        if ability.needsTarget {
            Feedback.select()
            mode = .abilityTargeting
            pendingTarget = nil
            refreshOverlays()
        } else {
            let events = state.useAbility(unitID: u.id)
            run(events) { [weak self] in self?.afterPlayerAction() }
        }
    }

    func confirmAbility() {
        guard let u = selectedUnit, let t = pendingTarget else { return }
        let events = state.useAbility(unitID: u.id, target: t)
        pendingTarget = nil
        mode = .idle
        guard !events.isEmpty else { return Feedback.error() }
        run(events) { [weak self] in self?.afterPlayerAction() }
    }

    func cancelAbility() {
        mode = .idle
        pendingTarget = nil
        refreshOverlays()
    }

    func waitSelected() {
        guard let u = selectedUnit else { return }
        Feedback.tap()
        state.wait(unitID: u.id)
        afterPlayerAction()
    }

    private func afterPlayerAction() {
        game?.persistBattle(state)
        if checkOutcome() { return }
        if let u = selectedUnit, u.isExhausted {
            selectNextReadyUnit()
        }
        refreshOverlays()
        if allUnitsDone {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                if self.allUnitsDone && self.state.phase == .player && !self.busy { self.endTurn() }
            }
        }
    }

    private func selectNextReadyUnit() {
        if let next = state.units(of: .player).first(where: { !$0.hasActed }) {
            selectedID = next.id
        } else {
            selectedID = nil
        }
        mode = .idle
    }

    func refreshOverlays() {
        let threat: [GridPoint]
        if let enemy = inspectedUnit {
            threat = threatTiles(for: enemy)
        } else {
            threat = []
        }
        scene.showOverlays(
            move: moveTiles,
            attack: mode == .abilityTargeting ? [] : attackTiles,
            ability: abilityTiles,
            threat: threat,
            selected: selectedUnit?.position ?? inspectedUnit?.position ?? inspectedTile,
            abilityIsSupport: selectedUnit?.kind == .engineer)
        if let u = selectedUnit, let t = pendingTarget, let dmg = pendingDamage {
            let isHeal = mode == .abilityTargeting && u.kind == .engineer
            scene.showPreview(from: u.position, to: t, damage: dmg, lethal: pendingIsLethal, support: isHeal)
        } else {
            scene.clearPreview()
        }
        objectWillChange.send()
    }

    /// Tiles an enemy could strike next turn (its movement plus attack range).
    func threatTiles(for enemy: BattleUnit) -> [GridPoint] {
        Array(state.threatTiles(for: enemy.id))
    }

    // MARK: Turn flow

    func endTurn() {
        guard canEndTurn else { return }
        selectedID = nil
        inspectedID = nil
        inspectedTile = nil
        pendingTarget = nil
        mode = .idle
        refreshOverlays()
        Task { await runEnemyPhase() }
    }

    private func runEnemyPhase() async {
        busy = true
        SoundEngine.shared.play(.turn)
        showBanner("Enemy Turn")
        let start = state.endPlayerTurn()
        await play(start)
        try? await Task.sleep(nanoseconds: scene.fastEnemies ? 250_000_000 : 600_000_000)

        var safety = 0
        while state.phase == .enemy, let id = TacticalAI.nextUnit(in: state), safety < 40 {
            safety += 1
            let decision = TacticalAI.decide(for: id, in: state)
            let events = TacticalAI.execute(decision, in: &state)
            objectWillChange.send()
            if !events.isEmpty {
                await play(events)
                try? await Task.sleep(nanoseconds: scene.fastEnemies ? 80_000_000 : 220_000_000)
            }
        }
        if state.phase == .enemy {
            let end = state.endEnemyTurn()
            await play(end)
        }
        busy = false
        if checkOutcome() { return }
        game?.persistBattle(state)
        SoundEngine.shared.play(.turn)
        showBanner("Your Turn · Round \(state.round)")
        selectNextReadyUnit()
        refreshOverlays()
    }

    private func play(_ events: [BattleEvent]) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            scene.play(events, state: state) { c.resume() }
        }
    }

    private func run(_ events: [BattleEvent], then: @escaping () -> Void) {
        busy = true
        scene.clearPreview()
        scene.showOverlays(move: [], attack: [], ability: [], threat: [], selected: nil, abilityIsSupport: false)
        scene.play(events, state: state) { [weak self] in
            self?.busy = false
            then()
        }
    }

    @discardableResult
    private func checkOutcome() -> Bool {
        guard state.phase == .victory || state.phase == .defeat, outcome == nil else { return outcome != nil }
        let victory = state.phase == .victory
        let summary = game?.completeBattle(state)
        selectedID = nil
        refreshOverlays()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if victory {
                SoundEngine.shared.play(.victory)
                Haptics.success()
                self.scene.celebrate()
            } else {
                SoundEngine.shared.play(.defeat)
                Haptics.warning()
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                self.outcome = Outcome(victory: victory, summary: summary)
            }
        }
        return true
    }

    func showBanner(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { banner = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if self.banner == text {
                withAnimation(.easeOut(duration: 0.3)) { self.banner = nil }
            }
        }
    }

    // MARK: Retry / leave

    func retry() {
        guard let game else { return }
        game.startMission(state.mission)
    }

    func retreat() {
        game?.persistBattle(nil)
        game?.leaveBattle()
    }

    // MARK: Screenshots

    func prepareScreenshot(_ scene: String) {
        switch scene {
        case "battle":
            // Select the Ranger and preview a shot so the screenshot shows every overlay type.
            if let ranger = state.units(of: .player).first(where: { $0.kind == .ranger }) {
                select(ranger.id)
                if let dest = moveTiles.sorted().first(where: { tile in
                    var sim = state
                    sim.move(unitID: ranger.id, to: tile)
                    return !sim.targets(for: ranger.id).isEmpty
                }) {
                    state.move(unitID: ranger.id, to: dest)
                    self.scene.sync(with: state)
                    if let t = attackTiles.first { setPending(t) }
                }
            }
            banner = nil
        case "victory":
            let mission = state.mission
            var profile = PlayerProfile()
            let summary = profile.applyVictory(mission: mission, stars: 3, squad: [.guardian, .ranger])
            outcome = Outcome(victory: true, summary: summary)
        default:
            if let ranger = state.units(of: .player).first(where: { $0.kind == .ranger }) { select(ranger.id) }
            banner = nil
        }
    }
}
