import SwiftUI
import GameCore

struct CampaignView: View {
    @EnvironmentObject var game: GameStore
    @State private var chapterID = 1
    @State private var briefing: MissionDefinition?

    var body: some View {
        ZStack {
            MenuBackdrop()
            VStack(spacing: 10) {
                ScreenHeader(title: "Campaign")
                ResourceBar()

                if game.dailyAvailable {
                    dailyCard.padding(.horizontal, 16)
                }

                TabView(selection: $chapterID) {
                    ForEach(Campaign.chapters) { chapter in
                        ChapterMap(chapter: chapter) { briefing = $0 }
                            .padding(.horizontal, 16)
                            .tag(chapter.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            chapterID = game.profile.nextMission?.chapter ?? game.profile.highestUnlockedChapter
        }
        .sheet(item: $briefing) { mission in
            MissionBriefSheet(mission: mission)
                .presentationDetents([.large])
                .presentationBackground(Palette.cream)
        }
    }

    private var dailyCard: some View {
        Button {
            Feedback.select()
            briefing = game.dailyMission
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Skirmish")
                        .font(GameFont.heading(17))
                        .foregroundStyle(Palette.cream)
                    Text("A new seeded battle every day. Bonus coins and supplies.")
                        .font(GameFont.body(12))
                        .foregroundStyle(Palette.cream.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.cream)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.slate))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.gold.opacity(0.7), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dailyButton")
    }
}

extension MissionDefinition {
    var biomeColors: (ground: Color, accent: Color) {
        switch biome {
        case .forest: return (Color(hex: 0x86B26F), Color(hex: 0x3F6B45))
        case .canyon: return (Color(hex: 0xE8CE9C), Color(hex: 0xB0683F))
        case .snow: return (Color(hex: 0xE6EDF2), Color(hex: 0x617C98))
        case .ruins: return (Color(hex: 0xA8A58A), Color(hex: 0x6E625A))
        }
    }
}

struct ChapterMap: View {
    @EnvironmentObject var game: GameStore
    var chapter: Chapter
    var onSelect: (MissionDefinition) -> Void

    private var colors: (ground: Color, accent: Color) {
        chapter.missions.first?.biomeColors ?? (Palette.forest, Palette.ink)
    }

    var body: some View {
        let unlocked = game.profile.isChapterUnlocked(chapter)
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("Chapter \(chapter.id)")
                    .font(GameFont.body(13))
                    .foregroundStyle(Palette.cream.opacity(0.7))
                Text(chapter.name)
                    .font(GameFont.title(26))
                    .foregroundStyle(Palette.cream)
                Text(chapter.tagline)
                    .font(GameFont.body(13))
                    .foregroundStyle(Palette.cream.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            GeometryReader { geo in
                let points = nodePositions(count: chapter.missions.count, in: geo.size)
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(colors.ground)
                        .overlay(BiomeDecor(biome: chapter.biome).clipShape(RoundedRectangle(cornerRadius: 26)))
                        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Palette.ink.opacity(0.5), lineWidth: 3))
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 8)

                    Path { p in
                        guard let first = points.first else { return }
                        p.move(to: first)
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Palette.cream.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 10]))

                    ForEach(Array(chapter.missions.enumerated()), id: \.element.id) { i, mission in
                        MissionNode(mission: mission,
                                    unlocked: game.profile.isMissionUnlocked(mission),
                                    stars: game.profile.missionStars[mission.id] ?? 0,
                                    isNext: game.profile.nextMission?.id == mission.id) {
                            onSelect(mission)
                        }
                        .position(points[i])
                    }

                    if !unlocked {
                        lockedOverlay
                    }
                }
            }
        }
        .padding(.bottom, 30)
    }

    private var lockedOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26).fill(Palette.ink.opacity(0.72))
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Palette.gold)
                Text("Locked")
                    .font(GameFont.title(24))
                    .foregroundStyle(Palette.cream)
                Text("Clear the previous chapter and upgrade your Command Center to level \(chapter.requiredCommandLevel).")
                    .font(GameFont.body(14))
                    .foregroundStyle(Palette.cream.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                if game.profile.chapterNeedsCommandUpgrade(chapter) {
                    Button("Go to Command Center") {
                        game.highlightedBuilding = .commandCenter
                        game.go(.outpost)
                    }
                    .buttonStyle(ChunkyButtonStyle(fullWidth: false))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func nodePositions(count: Int, in size: CGSize) -> [CGPoint] {
        (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(max(1, count - 1))
            let y = size.height * (0.92 - t * 0.84)
            let wave = sin(t * .pi * 2.6 + 0.4)
            let x = size.width * (0.5 + wave * 0.3)
            return CGPoint(x: x, y: y)
        }
    }
}

struct MissionNode: View {
    var mission: MissionDefinition
    var unlocked: Bool
    var stars: Int
    var isNext: Bool
    var action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: { if unlocked { Feedback.select(); action() } else { Feedback.error() } }) {
            VStack(spacing: 1) {
                ZStack {
                    Circle()
                        .fill(unlocked ? (isNext ? Palette.copper : Palette.cream) : Palette.ink.opacity(0.55))
                        .frame(width: 48, height: 48)
                        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                        .shadow(color: .black.opacity(0.35), radius: 0, y: 4)
                    if unlocked {
                        if case .defend = mission.objective {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(isNext ? Palette.cream : Palette.ink)
                        } else {
                            Text("\(mission.index)")
                                .font(GameFont.title(20))
                                .foregroundStyle(isNext ? Palette.cream : Palette.ink)
                        }
                    } else {
                        Image(systemName: "lock.fill").foregroundStyle(Palette.cream.opacity(0.7))
                    }
                }
                .scaleEffect(isNext && pulse ? 1.1 : 1)
                if stars > 0 {
                    StarRow(stars: stars, size: 10)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Palette.ink.opacity(0.75)))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 64, height: 64)
        .accessibilityLabel("Mission \(mission.index), \(mission.title), \(unlocked ? "\(stars) stars" : "locked")")
        .accessibilityIdentifier("mission-\(mission.id)")
        .onAppear {
            if isNext {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }
}

struct BiomeDecor: View {
    var biome: Biome

    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = UInt64(biome.rawValue.count * 97 + 3)
            func rnd() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 40) / CGFloat(1 << 24)
            }
            for _ in 0..<26 {
                let x = rnd() * size.width
                let y = rnd() * size.height
                let s = 10 + rnd() * 14
                var shape = Path()
                let color: Color
                switch biome {
                case .forest:
                    shape.move(to: CGPoint(x: x, y: y - s))
                    shape.addLine(to: CGPoint(x: x + s * 0.5, y: y))
                    shape.addLine(to: CGPoint(x: x - s * 0.5, y: y))
                    color = Color(hex: 0x3F6B45, opacity: 0.55)
                case .canyon:
                    shape.addRoundedRect(in: CGRect(x: x, y: y, width: s * 1.6, height: s * 0.6), cornerSize: CGSize(width: 4, height: 4))
                    color = Color(hex: 0xB0683F, opacity: 0.35)
                case .snow:
                    shape.move(to: CGPoint(x: x, y: y - s))
                    shape.addLine(to: CGPoint(x: x + s * 0.5, y: y))
                    shape.addLine(to: CGPoint(x: x - s * 0.5, y: y))
                    color = Color(hex: 0x617C98, opacity: 0.35)
                case .ruins:
                    shape.addRect(CGRect(x: x, y: y, width: s * 0.4, height: s))
                    color = Color(hex: 0x6E625A, opacity: 0.4)
                }
                ctx.fill(shape, with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

struct MissionBriefSheet: View {
    @EnvironmentObject var game: GameStore
    @Environment(\.dismiss) private var dismiss
    var mission: MissionDefinition

    var body: some View {
        let squad = game.profile.squad(for: mission)
        let layout = mission.parse()
        let enemyKinds = layout.enemies.map { $0.0 } + mission.reinforcements.map { $0.kind }
        let enemyCounts: [(kind: UnitClass, count: Int)] = UnitClass.enemyClasses.compactMap { kind -> (kind: UnitClass, count: Int)? in
            let n = enemyKinds.filter { $0 == kind }.count
            guard n > 0 else { return nil }
            return (kind: kind, count: n)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.chapter == 0 ? "Daily Skirmish" : "Mission \(mission.index)")
                        .font(GameFont.body(14))
                        .foregroundStyle(Palette.copper)
                    Text(mission.title)
                        .font(GameFont.title(30))
                        .foregroundStyle(Palette.ink)
                    Text(mission.briefing)
                        .font(GameFont.body(15))
                        .foregroundStyle(Palette.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Objective") {
                    HStack(spacing: 10) {
                        Image(systemName: mission.objective == .eliminate ? "scope" : "shield.lefthalf.filled")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.copper)
                        VStack(alignment: .leading) {
                            Text(mission.objective.title).font(GameFont.heading(16)).foregroundStyle(Palette.ink)
                            Text(mission.objective.summary).font(GameFont.body(13)).foregroundStyle(Palette.ink.opacity(0.75))
                            Text("3 stars: win, lose no one, finish by round \(mission.parRounds).")
                                .font(GameFont.body(12)).foregroundStyle(Palette.ink.opacity(0.6))
                        }
                    }
                }

                section("Enemies") {
                    HStack(spacing: 10) {
                        ForEach(enemyCounts.indices, id: \.self) { i in
                            let kind = enemyCounts[i].kind
                            let count = enemyCounts[i].count
                            VStack(spacing: 0) {
                                Image(uiImage: Art.unitImage(kind)).resizable().frame(width: 44, height: 54)
                                Text("\(kind == .warlord ? "Warlord" : kind.displayName) ×\(count)")
                                    .font(GameFont.body(11))
                                    .foregroundStyle(Palette.ink)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    if mission.enemyBonusLevel > 0 {
                        Text("Veteran raiders: level \(1 + mission.enemyBonusLevel)")
                            .font(GameFont.body(12)).foregroundStyle(Palette.danger)
                    }
                }

                section("Your Squad") {
                    HStack(spacing: 10) {
                        ForEach(squad, id: \.kind) { member in
                            VStack(spacing: 0) {
                                Image(uiImage: Art.unitImage(member.kind)).resizable().frame(width: 44, height: 54)
                                Text("\(member.kind.displayName) Lv\(member.level)")
                                    .font(GameFont.body(11))
                                    .foregroundStyle(Palette.ink)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                section(game.profile.isCompleted(mission.id) ? "Replay Reward" : "Reward") {
                    RewardRow(reward: game.profile.isCompleted(mission.id) ? mission.reward.scaled(0.4) : mission.reward)
                    if let unlock = mission.unlocks, !game.profile.unlockedClasses.contains(unlock) {
                        Label("Unlocks the \(unlock.displayName)", systemImage: "person.badge.plus")
                            .font(GameFont.heading(14))
                            .foregroundStyle(Palette.forest)
                    }
                }

                Button("Deploy Squad") {
                    dismiss()
                    game.startMission(mission)
                }
                .buttonStyle(ChunkyButtonStyle(color: Palette.copper))
                .accessibilityIdentifier("deployButton")
                .padding(.top, 6)
            }
            .padding(22)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(GameFont.heading(12))
                .tracking(1.5)
                .foregroundStyle(Palette.ink.opacity(0.55))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.sand.opacity(0.4)))
    }
}
