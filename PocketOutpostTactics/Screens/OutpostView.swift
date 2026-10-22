import SwiftUI
import SpriteKit
import GameCore

struct OutpostView: View {
    @EnvironmentObject var game: GameStore
    @State private var scene = OutpostScene(size: CGSize(width: 390, height: 844))
    @State private var selected: BuildingKind?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Frontier Outpost")
                                .font(GameFont.title(24))
                                .foregroundStyle(Palette.cream)
                                .shadow(color: .black.opacity(0.5), radius: 0, y: 2)
                                .accessibilityAddTraits(.isHeader)
                            ResourceBar()
                        }
                        Spacer()
                        IconButton(systemName: "gearshape.fill", label: "Settings") { game.go(.settings) }
                            .accessibilityIdentifier("settingsButton")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if let guide = game.guidance {
                        GuidanceCard(title: guide.title, detail: guide.detail)
                            .padding(.horizontal, 16)
                    }

                    Spacer()

                    buildingStrip
                    bottomButtons
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(12, geo.safeAreaInsets.bottom > 0 ? 4 : 16))
                }
            }
            .onAppear {
                scene.topInset = geo.safeAreaInsets.top + 150
                scene.bottomInset = geo.safeAreaInsets.bottom + 210
                scene.reduceMotion = game.reduceMotion
                scene.onSelect = { kind in
                    Feedback.select()
                    selected = kind
                }
                scene.configure(profile: game.profile, banner: game.banner.color, highlight: game.highlightedBuilding)
            }
        }
        .sheet(item: $selected) { kind in
            BuildingSheet(kind: kind) { upgraded in
                if upgraded {
                    scene.playUpgrade(kind, newLevel: game.profile.level(of: kind))
                    scene.configure(profile: game.profile, banner: game.banner.color, highlight: game.highlightedBuilding)
                }
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.cream)
        }
    }

    private var buildingStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BuildingKind.allCases) { kind in
                    let level = game.profile.level(of: kind)
                    let affordable = game.profile.upgradeCost(for: kind).map { game.profile.canAfford($0) } ?? false
                    Button {
                        Feedback.select()
                        selected = kind
                    } label: {
                        VStack(spacing: 2) {
                            Image(uiImage: Art.buildingImage(kind, level: level, banner: game.banner.color))
                                .resizable()
                                .frame(width: 46, height: 46)
                            Text(kind.displayName)
                                .font(GameFont.body(10))
                                .foregroundStyle(Palette.cream)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("Lv \(level)")
                                .font(GameFont.heading(11))
                                .foregroundStyle(Palette.gold)
                        }
                        .frame(width: 76, height: 84)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.ink.opacity(0.75)))
                        .overlay(alignment: .topTrailing) {
                            if affordable {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Palette.heal)
                                    .background(Circle().fill(Palette.ink))
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(game.highlightedBuilding == kind ? Palette.gold : Palette.cream.opacity(0.15),
                                              lineWidth: game.highlightedBuilding == kind ? 3 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(kind.displayName), level \(level)\(affordable ? ", upgrade available" : "")")
                    .accessibilityIdentifier("building-\(kind.rawValue)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 10) {
            Button {
                Feedback.tap()
                if !game.profile.isCompleted("c1m1"), let first = Campaign.chapters.first?.missions.first {
                    game.startMission(first)
                } else {
                    game.go(.campaign)
                }
            } label: {
                Label(game.profile.isCompleted("c1m1") ? "Campaign" : "To Battle!", systemImage: "flag.2.crossed.fill")
            }
            .buttonStyle(ChunkyButtonStyle(color: Palette.copper, height: 60))
            .accessibilityIdentifier("campaignButton")

            VStack(spacing: 8) {
                Button { game.go(.squad) } label: { Label("Squad", systemImage: "person.3.fill") }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.slate, height: 44))
                    .accessibilityIdentifier("squadButton")
                Button { game.go(.shop) } label: { Label("Banners", systemImage: "flag.fill") }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.forest, height: 44))
            }
            .frame(width: 150)
        }
    }
}

struct GuidanceCard: View {
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "scroll.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.copper)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GameFont.heading(15))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(GameFont.body(13))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.cream.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.parchmentShadow, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }
}

struct BuildingSheet: View {
    @EnvironmentObject var game: GameStore
    @Environment(\.dismiss) private var dismiss
    var kind: BuildingKind
    var onDone: (Bool) -> Void

    var body: some View {
        let level = game.profile.level(of: kind)
        let cost = game.profile.upgradeCost(for: kind)
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(uiImage: Art.buildingImage(kind, level: level, banner: game.banner.color))
                    .resizable()
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(Palette.sand.opacity(0.6)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.levelName(level))
                        .font(GameFont.title(24))
                        .foregroundStyle(Palette.ink)
                    Text("Level \(level) of \(kind.maxLevel)")
                        .font(GameFont.body(14))
                        .foregroundStyle(Palette.ink.opacity(0.7))
                    Text(kind.effect(at: level))
                        .font(GameFont.body(14))
                        .foregroundStyle(Palette.forest)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if let cost {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next: \(kind.levelName(level + 1)) (Lv \(level + 1))")
                        .font(GameFont.heading(16))
                        .foregroundStyle(Palette.ink)
                    Text(kind.effect(at: level + 1))
                        .font(GameFont.body(14))
                        .foregroundStyle(Palette.ink.opacity(0.85))
                    HStack {
                        ResourceChip(kind: .supplies, amount: cost.supplies)
                        if cost.timber > 0 { ResourceChip(kind: .timber, amount: cost.timber) }
                        Spacer()
                        Text("You have \(game.profile.supplies) / \(game.profile.timber)")
                            .font(GameFont.body(12))
                            .foregroundStyle(Palette.ink.opacity(0.6))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.sand.opacity(0.45)))

                Button(game.profile.canAfford(cost) ? "Upgrade" : "Need more resources") {
                    let ok = game.upgrade(kind)
                    onDone(ok)
                    if ok { dismiss() }
                }
                .buttonStyle(ChunkyButtonStyle(color: game.profile.canAfford(cost) ? Palette.forest : Palette.slate.opacity(0.6)))
                .disabled(!game.profile.canAfford(cost))
                .accessibilityIdentifier("upgradeButton")
            } else {
                Text("Fully upgraded. The whole frontier knows this place.")
                    .font(GameFont.body(15))
                    .foregroundStyle(Palette.forest)
                    .padding(.vertical, 20)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
