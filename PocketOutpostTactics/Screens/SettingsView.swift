import SwiftUI
import GameCore

struct SettingsView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var store: StoreManager
    @Environment(\.openURL) private var openURL
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            MenuBackdrop()
            VStack(spacing: 10) {
                ScreenHeader(title: "Settings")
                ScrollView {
                    VStack(spacing: 14) {
                        ParchmentPanel {
                            VStack(spacing: 12) {
                                toggle("Sound effects", \.soundOn)
                                toggle("Haptics", \.hapticsOn)
                                toggle("Reduce motion", \.reduceMotion)
                                toggle("Fast enemy turns", \.fastEnemyTurns)
                            }
                        }

                        ParchmentPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Your Journey").font(GameFont.heading(17)).foregroundStyle(Palette.ink)
                                let a = LocalAnalytics.summary(for: game.profile)
                                row("Battles won", "\(a.battlesWon)")
                                row("Stars earned", "\(a.stars) / \(Campaign.allMissions.count * 3)")
                                row("Upgrades built", "\(a.upgrades)")
                                row("Days played", "\(a.daysPlayed)")
                                Text("Stats are stored only on this device. Nothing is sent anywhere.")
                                    .font(GameFont.body(12)).foregroundStyle(Palette.ink.opacity(0.6))
                            }
                        }

                        ParchmentPanel {
                            VStack(spacing: 10) {
                                linkButton("Privacy Policy", "hand.raised.fill", GameStore.privacyPolicyURL)
                                linkButton("Support", "questionmark.circle.fill", GameStore.supportURL)
                                Button {
                                    Task { await store.restore() }
                                } label: {
                                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(GameFont.heading(15))
                                .foregroundStyle(Palette.ink)
                                .frame(minHeight: 44)
                                if let m = store.message {
                                    Text(m).font(GameFont.body(12)).foregroundStyle(Palette.forest)
                                }
                            }
                        }

                        Button("Reset Progress") { confirmReset = true }
                            .buttonStyle(ChunkyButtonStyle(color: Palette.danger, height: 46))

                        VStack(spacing: 4) {
                            Text("Pocket Outpost Tactics \(Bundle.main.versionString)")
                            Text("All art and sound effects are generated in code for this game.")
                        }
                        .font(GameFont.body(12))
                        .foregroundStyle(Palette.cream.opacity(0.6))
                        .multilineTextAlignment(.center)
                    }
                    .padding(16)
                }
            }
        }
        .confirmationDialog("Erase all progress? This can't be undone.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) { game.resetProgress() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func toggle(_ title: String, _ key: WritableKeyPath<PlayerProfile.Settings, Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { game.profile.settings[keyPath: key] },
            set: { v in game.updateSettings { $0[keyPath: key] = v } }))
            .font(GameFont.heading(15))
            .foregroundStyle(Palette.ink)
            .tint(Palette.forest)
            .frame(minHeight: 36)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(GameFont.body(14)).foregroundStyle(Palette.ink.opacity(0.8))
            Spacer()
            Text(value).font(GameFont.heading(14)).foregroundStyle(Palette.ink)
        }
    }

    private func linkButton(_ title: String, _ icon: String, _ url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "arrow.up.right")
            }
        }
        .font(GameFont.heading(15))
        .foregroundStyle(Palette.ink)
        .frame(minHeight: 44)
    }
}

extension Bundle {
    var versionString: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
