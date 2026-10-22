import SwiftUI
import GameCore

/// App-wide state: the save file, navigation, and the active battle.
@MainActor
final class GameStore: ObservableObject {
    enum Screen: Equatable {
        case title
        case outpost
        case campaign
        case squad
        case shop
        case settings
        case battle
    }

    @Published var profile: PlayerProfile
    @Published var screen: Screen = .title
    @Published var battle: BattleController?
    @Published var toast: String?
    /// Building to highlight in the outpost (first-session guidance).
    @Published var highlightedBuilding: BuildingKind?

    let saveStore: SaveStore
    /// Screenshot/demo mode never writes to disk.
    let isDemo: Bool
    let screenshotScene: String?

    static let privacyPolicyURL = URL(string: "https://github.com/surproductions/Pocket-Outpost-Tactics/blob/main/PRIVACY.md")!
    static let supportURL = URL(string: "https://github.com/surproductions/Pocket-Outpost-Tactics/blob/main/SUPPORT.md")!

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        saveStore = SaveStore.defaultStore()
        if let i = arguments.firstIndex(of: "-screenshot"), i + 1 < arguments.count {
            screenshotScene = arguments[i + 1]
            isDemo = true
            profile = DemoContent.profile(for: arguments[i + 1])
        } else {
            screenshotScene = nil
            isDemo = arguments.contains("-uiTesting")
            profile = isDemo ? PlayerProfile() : saveStore.loadProfile()
        }
        applySettings()
        profile.recordPlay(day: today)
        save()
    }

    func bootstrapScreenshotScene() {
        guard let scene = screenshotScene else { return }
        switch scene {
        case "outpost": screen = .outpost
        case "campaign": screen = .campaign
        case "squad": screen = .squad
        case "shop": screen = .shop
        case "battle", "victory", "ranged":
            let mission = DemoContent.battleMission(for: scene)
            startMission(mission)
            battle?.prepareScreenshot(scene)
        default: screen = .title
        }
    }

    var today: Int { PlayerProfile.dayNumber(for: Date()) }

    var banner: Cosmetics.Banner { Cosmetics.banner(id: profile.equippedBanner) }

    // MARK: Persistence

    func save() {
        guard !isDemo else { return }
        try? saveStore.save(profile)
    }

    func applySettings() {
        SoundEngine.shared.enabled = profile.settings.soundOn
        Haptics.enabled = profile.settings.hapticsOn
    }

    var reduceMotion: Bool {
        profile.settings.reduceMotion || UIAccessibility.isReduceMotionEnabled
    }

    func updateSettings(_ change: (inout PlayerProfile.Settings) -> Void) {
        change(&profile.settings)
        applySettings()
        save()
    }

    func resetProgress() {
        try? saveStore.reset()
        profile = PlayerProfile()
        profile.recordPlay(day: today)
        battle = nil
        save()
        screen = .title
    }

    // MARK: Navigation

    func go(_ screen: Screen) {
        Feedback.tap()
        withAnimation(.easeInOut(duration: 0.3)) { self.screen = screen }
    }

    func showToast(_ text: String) {
        toast = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if toast == text { toast = nil }
        }
    }

    // MARK: Battles

    func startMission(_ mission: MissionDefinition) {
        let squad = profile.squad(for: mission)
        let state = BattleState(mission: mission, squad: squad, modifiers: profile.squadModifiers)
        launch(state)
    }

    func resumeSavedBattle() -> Bool {
        guard !isDemo, let saved = saveStore.loadBattle(), saved.phase == .player else { return false }
        launch(saved)
        return true
    }

    var hasSavedBattle: Bool {
        !isDemo && saveStore.loadBattle()?.phase == .player
    }

    private func launch(_ state: BattleState) {
        let controller = BattleController(state: state, game: self)
        battle = controller
        profile.increment("battlesStarted")
        withAnimation(.easeInOut(duration: 0.35)) { screen = .battle }
    }

    func persistBattle(_ state: BattleState?) {
        guard !isDemo else { return }
        try? saveStore.saveBattle(state)
    }

    /// Called by the battle when it ends. Returns the rewards granted (nil on defeat).
    func completeBattle(_ state: BattleState) -> PlayerProfile.VictorySummary? {
        persistBattle(nil)
        guard state.phase == .victory else {
            profile.increment("battlesLost")
            save()
            return nil
        }
        let squad = state.units.filter { $0.faction == .player }.map(\.kind)
        let summary = profile.applyVictory(mission: state.mission, stars: state.stars, squad: squad)
        if state.mission.chapter == 0 {
            profile.dailyChallengeClearedDay = today
        }
        profile.increment("battlesWon")
        if state.mission.id == "c1m1" { highlightedBuilding = .watchtower }
        save()
        return summary
    }

    func leaveBattle(to screen: Screen = .outpost) {
        battle = nil
        withAnimation(.easeInOut(duration: 0.3)) { self.screen = screen }
    }

    // MARK: Outpost

    @discardableResult
    func upgrade(_ building: BuildingKind) -> Bool {
        guard profile.upgrade(building) else {
            Feedback.error()
            return false
        }
        profile.increment("upgrades")
        if highlightedBuilding == building { highlightedBuilding = nil }
        SoundEngine.shared.play(.upgrade)
        Haptics.success()
        save()
        return true
    }

    // MARK: Daily

    var dailyMission: MissionDefinition {
        MapGenerator.dailyChallenge(dayNumber: today, highestChapter: profile.highestUnlockedChapter)
    }

    var dailyAvailable: Bool {
        profile.isCompleted("c1m3") && profile.canClaimDaily(day: today)
    }

    // MARK: Guidance

    /// The single most useful next step, shown on the outpost screen.
    var guidance: (title: String, detail: String)? {
        if !profile.isCompleted("c1m1") {
            return ("Raiders spotted!", "A raider is prowling near the outpost. Lead your Guardian into battle.")
        }
        if profile.level(of: .watchtower) == 1, !profile.isCompleted("c1m2") {
            return ("Upgrade the Watchtower", "Tap the tower. Your Ranger will deal +1 damage.")
        }
        if let next = profile.nextMission {
            if next.chapter > 1 || profile.isCompleted("c1m2") {
                if let ch = Campaign.chapters.first(where: { profile.chapterNeedsCommandUpgrade($0) }) {
                    return ("New territory ahead", "Upgrade the Command Center to march on \(ch.name).")
                }
            }
            return ("Next: \(next.title)", next.briefing)
        }
        if let ch = Campaign.chapters.first(where: { profile.chapterNeedsCommandUpgrade($0) }) {
            return ("New territory ahead", "Upgrade the Command Center to march on \(ch.name).")
        }
        return ("The frontier is safe", "Replay missions for three stars, or take on today's Daily Skirmish.")
    }
}
