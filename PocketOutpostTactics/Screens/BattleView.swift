import SwiftUI
import SpriteKit
import GameCore

struct BattleView: View {
    @EnvironmentObject var game: GameStore
    @ObservedObject var controller: BattleController

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: controller.scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .accessibilityLabel("Battlefield")
                    .accessibilityHint("Use the unit panel below to act. Tap tiles to move and attack.")

                VStack(spacing: 8) {
                    topBar
                    if let hint = controller.tutorialHint {
                        HintBubble(text: hint)
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                    }
                    Spacer()
                    bottomPanel
                        .padding(.horizontal, 12)
                        .padding(.bottom, max(8, geo.safeAreaInsets.bottom > 0 ? 0 : 10))
                }
                .padding(.top, 6)

                if let banner = controller.banner {
                    PhaseBanner(text: banner)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                if let outcome = controller.outcome {
                    OutcomeOverlay(controller: controller, outcome: outcome)
                        .transition(.opacity)
                }

                if controller.paused {
                    PauseOverlay(controller: controller)
                        .transition(.opacity)
                }
            }
            .onAppear {
                controller.scene.boardInsets = UIEdgeInsets(
                    top: geo.safeAreaInsets.top + 112, left: 6,
                    bottom: geo.safeAreaInsets.bottom + 196, right: 6)
                controller.refreshOverlays()
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            IconButton(systemName: "pause.fill", label: "Pause") {
                Feedback.tap()
                withAnimation { controller.paused = true }
            }
            .accessibilityIdentifier("pauseButton")
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.state.mission.title)
                    .font(GameFont.heading(16))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Round \(controller.state.round)")
                    Text("·")
                    Text(controller.objectiveStatus)
                }
                .font(GameFont.body(12))
                .foregroundStyle(Palette.sand)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            Button {
                Feedback.tap()
                controller.endTurn()
            } label: {
                Text(controller.state.phase == .enemy ? "Enemy…" : "End Turn")
                    .frame(minWidth: 92)
            }
            .buttonStyle(ChunkyButtonStyle(color: controller.allUnitsDone ? Palette.copper : Palette.slate, height: 44, fullWidth: false))
            .disabled(!controller.canEndTurn)
            .opacity(controller.canEndTurn ? 1 : 0.6)
            .accessibilityIdentifier("endTurnButton")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Palette.ink.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.cream.opacity(0.15), lineWidth: 1))
        )
        .padding(.horizontal, 10)
    }

    // MARK: Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        if let u = controller.selectedUnit {
            UnitPanel(unit: u, controller: controller)
        } else if let e = controller.inspectedUnit {
            EnemyPanel(unit: e)
        } else if let tile = controller.inspectedTile {
            TerrainPanel(terrain: controller.state.terrain(at: tile), structure: controller.state.structures[tile])
        } else {
            SquadStrip(controller: controller)
        }
    }
}

// MARK: - Panels

struct UnitPanel: View {
    var unit: BattleUnit
    @ObservedObject var controller: BattleController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(uiImage: Art.unitImage(unit.kind))
                    .resizable()
                    .frame(width: 50, height: 61)
                    .background(Circle().fill(Palette.sand.opacity(0.5)).frame(width: 54, height: 54).offset(y: 6))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(unit.kind.displayName).font(GameFont.heading(18)).foregroundStyle(Palette.ink)
                        Text("Lv \(unit.level)").font(GameFont.body(13)).foregroundStyle(Palette.copper)
                    }
                    HPBar(current: unit.hp, max: unit.stats.maxHP)
                    HStack(spacing: 5) {
                        StatPill(icon: "bolt.fill", value: "\(unit.stats.attack)", label: "Attack", tint: Palette.danger)
                        StatPill(icon: "shield.fill", value: "\(unit.effectiveDefense)", label: "Defense", tint: Palette.slate)
                        StatPill(icon: "figure.walk", value: "\(unit.movePoints)", label: "Movement left", tint: Palette.forest)
                        StatPill(icon: "scope", value: unit.stats.minRange == unit.stats.maxRange ? "\(unit.stats.maxRange)" : "\(unit.stats.minRange)-\(unit.stats.maxRange)", label: "Range", tint: Palette.copper)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    controller.deselect()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(Palette.ink.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Deselect")
            }

            if let target = controller.pendingTarget, let dmg = controller.pendingDamage {
                previewRow(target: target, damage: dmg)
            } else {
                actionRow
            }
        }
        .padding(14)
        .background(panelBackground)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            if let ability = unit.kind.ability {
                Button {
                    if controller.mode == .abilityTargeting { controller.cancelAbility() } else { controller.beginAbility() }
                } label: {
                    VStack(spacing: 0) {
                        Text(controller.mode == .abilityTargeting ? "Cancel" : ability.displayName)
                            .font(GameFont.heading(15))
                        Text(unit.abilityCooldown > 0 ? "Ready in \(unit.abilityCooldown)" : (unit.hasActed ? "Already acted" : abilityHint(ability)))
                            .font(GameFont.body(10))
                            .opacity(0.85)
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Palette.gold, textColor: Palette.ink, height: 50))
                .disabled(!unit.canUseAbility && controller.mode != .abilityTargeting)
                .opacity(unit.canUseAbility || controller.mode == .abilityTargeting ? 1 : 0.5)
                .accessibilityHint(ability.description)
                .accessibilityIdentifier("abilityButton")
            }
            Button {
                controller.waitSelected()
            } label: {
                Text(unit.hasActed ? "Done" : "Wait")
            }
            .buttonStyle(ChunkyButtonStyle(color: Palette.slate, height: 50))
            .frame(width: 110)
            .accessibilityIdentifier("waitButton")
        }
    }

    private func abilityHint(_ ability: AbilityKind) -> String {
        switch ability {
        case .shieldWall: return "+2 DEF, guard allies"
        case .precisionShot: return "Range 2-4, +2 dmg"
        case .dash: return "+3 move"
        case .fieldKit: return "Build or repair"
        case .smash: return "+3 damage"
        }
    }

    private func previewRow(target: GridPoint, damage: Int) -> some View {
        let state = controller.state
        let name: String
        var remaining = 0
        if let t = state.unit(at: target) {
            name = t.kind.displayName
            remaining = t.hp
        } else if let s = state.structures[target] {
            name = s.kind == .gate ? "Gate" : "Barricade"
            remaining = s.hp
        } else {
            name = "Empty ground"
        }
        let support = controller.mode == .abilityTargeting && unit.kind == .engineer
        let text: String
        if support {
            text = state.unit(at: target) != nil || state.structures[target] != nil ? "Repair \(name)" : "Build a barricade here"
        } else {
            text = controller.pendingIsLethal ? "\(name): \(damage) damage, defeated!" : "\(name): \(damage) damage (\(remaining) → \(max(0, remaining - damage)) HP)"
        }
        return HStack(spacing: 8) {
            Text(text)
                .font(GameFont.heading(14))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(support ? "Confirm" : "Attack!") {
                if controller.mode == .abilityTargeting { controller.confirmAbility() } else { controller.confirmAttack() }
            }
            .buttonStyle(ChunkyButtonStyle(color: support ? Palette.forest : Palette.danger, height: 48, fullWidth: false))
            .accessibilityIdentifier("confirmButton")
        }
    }
}

struct EnemyPanel: View {
    var unit: BattleUnit

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(uiImage: Art.unitImage(unit.kind))
                .resizable()
                .frame(width: 50, height: 61)
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.kind.displayName).font(GameFont.heading(17)).foregroundStyle(Palette.ink)
                HPBar(current: unit.hp, max: unit.stats.maxHP, color: Palette.danger)
                HStack(spacing: 5) {
                    StatPill(icon: "bolt.fill", value: "\(unit.stats.attack)", label: "Attack", tint: Palette.danger)
                    StatPill(icon: "shield.fill", value: "\(unit.effectiveDefense)", label: "Defense", tint: Palette.slate)
                    StatPill(icon: "figure.walk", value: "\(unit.stats.move)", label: "Movement", tint: Palette.forest)
                    StatPill(icon: "scope", value: unit.stats.minRange == unit.stats.maxRange ? "\(unit.stats.maxRange)" : "\(unit.stats.minRange)-\(unit.stats.maxRange)", label: "Range", tint: Palette.copper)
                }
                Text(unit.kind.passiveText ?? unit.kind.role)
                    .font(GameFont.body(12))
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Orange tiles: where it can strike next turn.")
                    .font(GameFont.body(11))
                    .foregroundStyle(Palette.copper)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(panelBackground)
        .accessibilityElement(children: .combine)
    }
}

struct TerrainPanel: View {
    var terrain: Terrain
    var structure: Structure?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: structure != nil ? "shield.checkered" : "map.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.forest)
            VStack(alignment: .leading, spacing: 3) {
                if let s = structure {
                    Text(s.kind == .gate ? "Outpost Gate" : "Barricade").font(GameFont.heading(17)).foregroundStyle(Palette.ink)
                    Text(s.kind == .gate ? "Protect it! If it falls, the mission is lost. \(s.hp)/\(s.maxHP) HP"
                         : "Blocks movement. Units next to it get -1 damage taken. \(s.hp)/\(s.maxHP) HP")
                        .font(GameFont.body(13)).foregroundStyle(Palette.ink.opacity(0.8))
                } else {
                    Text(terrain.displayName).font(GameFont.heading(17)).foregroundStyle(Palette.ink)
                    Text(terrain.rulesText).font(GameFont.body(13)).foregroundStyle(Palette.ink.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(panelBackground)
        .accessibilityElement(children: .combine)
    }
}

struct SquadStrip: View {
    @ObservedObject var controller: BattleController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(controller.state.phase == .player ? "Your squad: tap a unit to give orders" : "Raiders are moving…")
                .font(GameFont.heading(13))
                .foregroundStyle(Palette.ink.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(controller.state.units(of: .player)) { u in
                    Button {
                        controller.select(u.id)
                    } label: {
                        VStack(spacing: 2) {
                            Image(uiImage: Art.unitImage(u.kind))
                                .resizable()
                                .frame(width: 38, height: 46)
                                .saturation(u.isExhausted ? 0.2 : 1)
                            HPBar(current: u.hp, max: u.stats.maxHP, compact: true)
                                .frame(width: 52)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.sand.opacity(u.isExhausted ? 0.2 : 0.5)))
                    }
                    .buttonStyle(.plain)
                    .disabled(controller.state.phase != .player)
                    .accessibilityLabel("\(u.kind.displayName), \(u.hp) of \(u.stats.maxHP) health\(u.isExhausted ? ", done" : "")")
                    .accessibilityIdentifier("squad-\(u.kind.rawValue)")
                }
            }
        }
        .padding(14)
        .background(panelBackground)
    }
}

private var panelBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Palette.cream)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.parchmentShadow, lineWidth: 3))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
}

struct HPBar: View {
    var current: Int
    var max: Int
    var color: Color = Palette.heal
    var compact = false

    var body: some View {
        let frac = max > 0 ? CGFloat(Swift.max(0, current)) / CGFloat(max) : 0
        HStack(spacing: 6) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.2))
                    Capsule().fill(frac < 0.35 ? Palette.gold : color).frame(width: g.size.width * frac)
                }
            }
            .frame(height: compact ? 6 : 9)
            if !compact {
                Text("\(current)/\(max)")
                    .font(GameFont.heading(12))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: compact ? nil : 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health \(current) of \(max)")
    }
}

struct HintBubble: View {
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill").foregroundStyle(Palette.gold)
            Text(text)
                .font(GameFont.body(14))
                .foregroundStyle(Palette.cream)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.slate.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.gold.opacity(0.6), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct PhaseBanner: View {
    var text: String

    var body: some View {
        Text(text)
            .font(GameFont.title(28))
            .foregroundStyle(Palette.cream)
            .shadow(color: Palette.ink, radius: 0, y: 3)
            .padding(.horizontal, 36)
            .padding(.vertical, 14)
            .background(RibbonShape().fill(text.hasPrefix("Enemy") ? Palette.danger : Palette.copper))
            .overlay(RibbonShape().stroke(Palette.ink.opacity(0.6), lineWidth: 2.5))
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Overlays

struct OutcomeOverlay: View {
    @EnvironmentObject var game: GameStore
    @ObservedObject var controller: BattleController
    var outcome: BattleController.Outcome
    @State private var showStars = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            ParchmentPanel(padding: 22) {
                VStack(spacing: 14) {
                    RibbonTitle(text: outcome.victory ? "Victory!" : "Defeat")
                    if outcome.victory, let summary = outcome.summary {
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < showStars ? "star.fill" : "star")
                                    .font(.system(size: 38, weight: .black))
                                    .foregroundStyle(i < showStars ? Palette.gold : Palette.ink.opacity(0.25))
                                    .scaleEffect(i < showStars ? 1 : 0.8)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(summary.stars) of 3 stars")
                        Text(starExplanation(summary.stars))
                            .font(GameFont.body(13))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                            .multilineTextAlignment(.center)
                        VStack(spacing: 6) {
                            Text(summary.firstClear ? "Rewards" : "Replay rewards")
                                .font(GameFont.heading(14))
                                .foregroundStyle(Palette.ink.opacity(0.6))
                            RewardRow(reward: summary.reward)
                        }
                        if let unlocked = summary.unlocked {
                            HStack(spacing: 10) {
                                Image(uiImage: Art.unitImage(unlocked)).resizable().frame(width: 52, height: 64)
                                VStack(alignment: .leading) {
                                    Text("New recruit: \(unlocked.displayName)!")
                                        .font(GameFont.heading(16)).foregroundStyle(Palette.forest)
                                    Text(unlocked.role).font(GameFont.body(12)).foregroundStyle(Palette.ink.opacity(0.75))
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.heal.opacity(0.2)))
                        }
                        if !summary.levelUps.isEmpty {
                            Text("Level up: " + summary.levelUps.map(\.displayName).joined(separator: ", "))
                                .font(GameFont.heading(14))
                                .foregroundStyle(Palette.copper)
                        }
                    } else {
                        Text(defeatTip)
                            .font(GameFont.body(15))
                            .foregroundStyle(Palette.ink.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 10) {
                        if outcome.victory {
                            Button("Return to Outpost") { game.leaveBattle(to: .outpost) }
                                .buttonStyle(ChunkyButtonStyle(color: Palette.copper))
                                .accessibilityIdentifier("continueButton")
                            if let next = nextMission, game.profile.isMissionUnlocked(next), controller.state.mission.id != "c1m1" {
                                Button("Next: \(next.title)") { game.startMission(next) }
                                    .buttonStyle(ChunkyButtonStyle(color: Palette.forest, height: 46))
                            }
                        } else {
                            Button("Try Again") { controller.retry() }
                                .buttonStyle(ChunkyButtonStyle(color: Palette.copper))
                                .accessibilityIdentifier("retryButton")
                            Button("Back to Outpost") { game.leaveBattle(to: .outpost) }
                                .buttonStyle(ChunkyButtonStyle(color: Palette.slate, height: 46))
                        }
                    }
                }
                .frame(maxWidth: 340)
            }
            .padding(24)
        }
        .onAppear {
            guard let stars = outcome.summary?.stars else { return }
            for i in 0..<stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { showStars = i + 1 }
                    SoundEngine.shared.play(.coin)
                    Haptics.tap()
                }
            }
        }
    }

    private var nextMission: MissionDefinition? {
        controller.state.mission.chapter == 0 ? nil : Campaign.mission(after: controller.state.mission.id)
    }

    private func starExplanation(_ stars: Int) -> String {
        let par = controller.state.mission.parRounds
        var parts: [String] = ["★ Won"]
        parts.append(controller.state.playerUnitsLost == 0 ? "★ No one lost" : "☆ Lose no one")
        parts.append(controller.state.round <= par ? "★ Within \(par) rounds" : "☆ Finish by round \(par)")
        return parts.joined(separator: "   ")
    }

    private var defeatTip: String {
        switch controller.state.mission.objective {
        case .defend:
            return "The gate fell. Engineers can repair it and build barricades; keep your Guardian between raiders and the gate."
        case .eliminate:
            return "Your squad was overrun. Tip: tap enemies to see their reach, fight from forest cover, and focus fire on one target at a time. Outpost upgrades make your squad stronger."
        }
    }
}

struct PauseOverlay: View {
    @EnvironmentObject var game: GameStore
    @ObservedObject var controller: BattleController
    @State private var confirmRetreat = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { withAnimation { controller.paused = false } }
            ParchmentPanel(padding: 22) {
                VStack(spacing: 14) {
                    RibbonTitle(text: "Paused")
                    VStack(alignment: .leading, spacing: 6) {
                        rule("Move", "Tap a unit, then a blue tile.")
                        rule("Attack", "Tap a red target to preview, tap again to strike.")
                        rule("Damage", "Attack minus defense minus cover (minimum 1). No dice, no surprises.")
                        rule("Cover", "Forest and ruins: -1 damage. Next to a barricade: -1 damage.")
                        rule("Turns", "Each unit can move, then act once. Raiders act after you.")
                    }
                    Toggle("Sound", isOn: Binding(get: { game.profile.settings.soundOn },
                                                  set: { v in game.updateSettings { $0.soundOn = v } }))
                    Toggle("Fast enemy turns", isOn: Binding(get: { game.profile.settings.fastEnemyTurns },
                                                             set: { v in
                                                                 game.updateSettings { $0.fastEnemyTurns = v }
                                                                 controller.scene.fastEnemies = v
                                                             }))
                    Button("Resume") { withAnimation { controller.paused = false } }
                        .buttonStyle(ChunkyButtonStyle(color: Palette.forest))
                    Button("Restart Mission") { controller.retry() }
                        .buttonStyle(ChunkyButtonStyle(color: Palette.slate, height: 46))
                    Button("Retreat to Outpost") { confirmRetreat = true }
                        .buttonStyle(ChunkyButtonStyle(color: Palette.danger, height: 46))
                }
                .font(GameFont.body(15))
                .foregroundStyle(Palette.ink)
                .tint(Palette.forest)
                .frame(maxWidth: 340)
            }
            .padding(24)
        }
        .confirmationDialog("Retreat? This battle's progress will be lost.", isPresented: $confirmRetreat, titleVisibility: .visible) {
            Button("Retreat", role: .destructive) { controller.retreat() }
            Button("Keep Fighting", role: .cancel) {}
        }
    }

    private func rule(_ title: String, _ text: String) -> some View {
        (Text(title + ": ").font(GameFont.heading(13)) + Text(text).font(GameFont.body(13)))
            .foregroundStyle(Palette.ink.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }
}
