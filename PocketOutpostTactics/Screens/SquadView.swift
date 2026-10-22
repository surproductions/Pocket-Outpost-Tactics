import SwiftUI
import GameCore

struct SquadView: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        ZStack {
            MenuBackdrop()
            VStack(spacing: 10) {
                ScreenHeader(title: "Your Squad")
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(UnitClass.playerClasses, id: \.self) { kind in
                            SquadCard(kind: kind)
                        }
                        Text("Squad members level up from battle experience. Barracks and Watchtower upgrades boost the whole squad.")
                            .font(GameFont.body(13))
                            .foregroundStyle(Palette.cream.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(16)
                }
            }
        }
    }
}

struct SquadCard: View {
    @EnvironmentObject var game: GameStore
    var kind: UnitClass

    private var unlockMission: MissionDefinition? {
        Campaign.allMissions.first { $0.unlocks == kind }
    }

    var body: some View {
        let unlocked = game.profile.unlockedClasses.contains(kind)
        let level = game.profile.level(for: kind)
        let xp = game.profile.xp(for: kind)
        let stats = Progression.stats(for: kind, level: level, modifiers: game.profile.squadModifiers)
        ParchmentPanel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(uiImage: Art.unitImage(kind))
                    .resizable()
                    .frame(width: 66, height: 81)
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.45)
                    .background(Circle().fill(Palette.sand.opacity(0.6)).frame(width: 70, height: 70).offset(y: 8))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(kind.displayName).font(GameFont.title(20)).foregroundStyle(Palette.ink)
                        if unlocked {
                            Text("Lv \(level)").font(GameFont.heading(14)).foregroundStyle(Palette.copper)
                        }
                        Spacer()
                    }
                    Text(kind.role).font(GameFont.body(13)).foregroundStyle(Palette.ink.opacity(0.8))
                    if unlocked {
                        HStack(spacing: 5) {
                            StatPill(icon: "heart.fill", value: "\(stats.maxHP)", label: "Health", tint: Palette.heal)
                            StatPill(icon: "bolt.fill", value: "\(stats.attack)", label: "Attack", tint: Palette.danger)
                            StatPill(icon: "shield.fill", value: "\(stats.defense)", label: "Defense", tint: Palette.slate)
                            StatPill(icon: "figure.walk", value: "\(stats.move)", label: "Movement", tint: Palette.forest)
                        }
                        if let ability = kind.ability {
                            (Text(ability.displayName + ": ").font(GameFont.heading(13)) + Text(ability.description).font(GameFont.body(13)))
                                .foregroundStyle(Palette.ink.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let passive = kind.passiveText {
                            Text(passive).font(GameFont.body(12)).foregroundStyle(Palette.forest)
                        }
                        if let toNext = Progression.xpToNext(xp: xp), let perk = Progression.nextLevelPerk(for: level) {
                            let span = Progression.xpThresholds[level] - Progression.xpThresholds[level - 1]
                            VStack(alignment: .leading, spacing: 3) {
                                ProgressView(value: Double(span - toNext), total: Double(span))
                                    .tint(Palette.gold)
                                Text("\(toNext) XP to level \(level + 1): \(perk)")
                                    .font(GameFont.body(11)).foregroundStyle(Palette.ink.opacity(0.6))
                            }
                        } else {
                            Text("Max level").font(GameFont.heading(12)).foregroundStyle(Palette.gold)
                        }
                    } else if let m = unlockMission {
                        Label("Joins after Mission \(m.index): \(m.title)", systemImage: "lock.fill")
                            .font(GameFont.heading(13))
                            .foregroundStyle(Palette.slate)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
