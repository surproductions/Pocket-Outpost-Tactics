import SwiftUI
import GameCore

struct TitleView: View {
    @EnvironmentObject var game: GameStore
    @State private var appeared = false

    var body: some View {
        ZStack {
            MenuBackdrop()
            VStack(spacing: 18) {
                Spacer(minLength: 30)
                VStack(spacing: 2) {
                    Text("POCKET")
                        .font(GameFont.title(26))
                        .tracking(8)
                        .foregroundStyle(Palette.sand)
                    Text("Outpost")
                        .font(GameFont.title(58))
                        .foregroundStyle(Palette.cream)
                    Text("TACTICS")
                        .font(GameFont.title(30))
                        .tracking(10)
                        .foregroundStyle(Palette.copper)
                }
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pocket Outpost Tactics")

                Text("Small Squads. Big Strategies.")
                    .font(GameFont.body(16))
                    .foregroundStyle(Palette.cream.opacity(0.85))

                ZStack {
                    Ellipse()
                        .fill(Palette.forest)
                        .frame(width: 290, height: 90)
                        .overlay(Ellipse().strokeBorder(Palette.ink.opacity(0.5), lineWidth: 3))
                        .offset(y: 70)
                    HStack(alignment: .bottom, spacing: -24) {
                        Image(uiImage: Art.buildingImage(.watchtower, level: 3, banner: game.banner.color))
                            .resizable().frame(width: 130, height: 130)
                        Image(uiImage: Art.buildingImage(.commandCenter, level: 2, banner: game.banner.color))
                            .resizable().frame(width: 140, height: 140)
                    }
                    HStack(spacing: 4) {
                        ForEach([UnitClass.guardian, .ranger, .scout, .engineer], id: \.self) { kind in
                            Image(uiImage: Art.unitImage(kind))
                                .resizable()
                                .frame(width: 54, height: 66)
                                .offset(y: appeared ? 0 : 12)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(UnitClass.playerClasses.firstIndex(of: kind) ?? 0) * 0.08), value: appeared)
                        }
                    }
                    .offset(y: 78)
                }
                .frame(height: 230)
                .accessibilityHidden(true)

                Spacer()

                VStack(spacing: 14) {
                    if game.hasSavedBattle {
                        Button("Resume Battle") {
                            Feedback.tap()
                            _ = game.resumeSavedBattle()
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Palette.forest))
                    }
                    Button(game.profile.isCompleted("c1m1") ? "Enter Outpost" : "Play") {
                        game.go(.outpost)
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .accessibilityIdentifier("playButton")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear { appeared = true }
    }
}
