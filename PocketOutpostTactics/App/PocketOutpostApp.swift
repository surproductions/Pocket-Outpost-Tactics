import SwiftUI

@main
struct PocketOutpostApp: App {
    @StateObject private var game = GameStore()
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(storeManager)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .task {
                    SoundEngine.shared.prepare()
                    await storeManager.load()
                    if let banner = Cosmetics.banners.first(where: { $0.price == .supporterPack }),
                       storeManager.ownsSupporterPack, !game.profile.ownedCosmetics.contains(banner.id) {
                        game.profile.ownedCosmetics.append(banner.id)
                        game.save()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                // Interruption-safe: the profile and any battle in progress are saved immediately.
                game.save()
                if let battle = game.battle, battle.outcome == nil, !battle.busy {
                    game.persistBattle(battle.state)
                }
            }
        }
    }
}
