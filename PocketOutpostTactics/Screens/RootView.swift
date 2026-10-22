import SwiftUI

struct RootView: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        ZStack {
            Palette.night.ignoresSafeArea()
            switch game.screen {
            case .title:
                TitleView().transition(.opacity)
            case .outpost:
                OutpostView().transition(.opacity)
            case .campaign:
                CampaignView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .squad:
                SquadView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .shop:
                ShopView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .settings:
                SettingsView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .battle:
                if let battle = game.battle {
                    BattleView(controller: battle)
                        .id(ObjectIdentifier(battle))
                        .transition(.opacity)
                }
            }

            if let toast = game.toast {
                VStack {
                    Text(toast)
                        .font(GameFont.heading(16))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Palette.gold))
                        .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.5), lineWidth: 2))
                        .shadow(radius: 8)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.toast)
        .onAppear { game.bootstrapScreenshotScene() }
    }
}

/// Shared top bar for menu screens.
struct ScreenHeader: View {
    @EnvironmentObject var game: GameStore
    var title: String
    var back: GameStore.Screen = .outpost

    var body: some View {
        HStack {
            IconButton(systemName: "chevron.left", label: "Back") { game.go(back) }
                .accessibilityIdentifier("backButton")
            Spacer()
            RibbonTitle(text: title)
            Spacer()
            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
