import SwiftUI
import StoreKit

struct ShopView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var store: StoreManager

    var body: some View {
        ZStack {
            MenuBackdrop()
            VStack(spacing: 10) {
                ScreenHeader(title: "Banners")
                ResourceBar()
                ScrollView {
                    VStack(spacing: 14) {
                        Text("Banners fly over your outpost. They're purely cosmetic: nothing for sale changes combat.")
                            .font(GameFont.body(13))
                            .foregroundStyle(Palette.cream.opacity(0.8))
                            .multilineTextAlignment(.center)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Cosmetics.banners) { banner in
                                BannerCard(banner: banner)
                            }
                        }

                        if store.supporterProduct != nil || store.ownsSupporterPack {
                            supporterCard
                        }

                        Button("Restore Purchases") {
                            Task { await store.restore() }
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Palette.slate, height: 44))
                        .padding(.top, 4)

                        if let message = store.message {
                            Text(message)
                                .font(GameFont.body(13))
                                .foregroundStyle(Palette.gold)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onChange(of: store.ownsSupporterPack) { _, owns in
            if owns, !game.profile.ownedCosmetics.contains("sunburst") {
                game.profile.ownedCosmetics.append("sunburst")
                game.save()
            }
        }
    }

    private var supporterCard: some View {
        ParchmentPanel(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill").foregroundStyle(Palette.danger)
                    Text("Supporter Pack").font(GameFont.title(20)).foregroundStyle(Palette.ink)
                }
                Text("Support an independent game and raise the golden Sunburst banner over your outpost. A one-time, cosmetic-only purchase.")
                    .font(GameFont.body(13))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                if store.ownsSupporterPack {
                    Label("Thank you! Unlocked.", systemImage: "checkmark.seal.fill")
                        .font(GameFont.heading(15))
                        .foregroundStyle(Palette.forest)
                } else if let product = store.supporterProduct {
                    Button("Buy for \(product.displayPrice)") {
                        Task { await store.purchaseSupporterPack() }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.copper, height: 48))
                }
            }
        }
    }
}

struct BannerCard: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var store: StoreManager
    var banner: Cosmetics.Banner

    private var owned: Bool {
        switch banner.price {
        case .free: return true
        case .supporterPack: return store.ownsSupporterPack || game.profile.ownedCosmetics.contains(banner.id)
        case .coins: return game.profile.ownedCosmetics.contains(banner.id)
        }
    }

    var body: some View {
        let equipped = game.profile.equippedBanner == banner.id
        VStack(spacing: 8) {
            Canvas { ctx, size in
                var pole = Path()
                pole.addRoundedRect(in: CGRect(x: size.width / 2 - 22, y: 6, width: 4, height: size.height - 8), cornerSize: CGSize(width: 2, height: 2))
                ctx.fill(pole, with: .color(Palette.ink))
                var flag = Path()
                flag.move(to: CGPoint(x: size.width / 2 - 18, y: 8))
                flag.addQuadCurve(to: CGPoint(x: size.width / 2 + 30, y: 18), control: CGPoint(x: size.width / 2 + 6, y: 2))
                flag.addLine(to: CGPoint(x: size.width / 2 + 24, y: 30))
                flag.addQuadCurve(to: CGPoint(x: size.width / 2 - 18, y: 40), control: CGPoint(x: size.width / 2, y: 34))
                flag.closeSubpath()
                ctx.fill(flag, with: .color(banner.swiftUIColor))
                ctx.stroke(flag, with: .color(Palette.ink), lineWidth: 2)
            }
            .frame(height: 64)
            Text(banner.name)
                .font(GameFont.heading(13))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 34)
            Button(action: tap) {
                Text(buttonTitle(equipped: equipped))
                    .font(GameFont.heading(13))
            }
            .buttonStyle(ChunkyButtonStyle(color: equipped ? Palette.forest : (owned ? Palette.slate : Palette.copper), height: 38))
            .disabled(equipped || (!owned && banner.price == .supporterPack))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.cream))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(equipped ? Palette.gold : Palette.parchmentShadow, lineWidth: equipped ? 3 : 2))
        .accessibilityElement(children: .contain)
    }

    private func buttonTitle(equipped: Bool) -> String {
        if equipped { return "Flying" }
        if owned { return "Raise" }
        switch banner.price {
        case .coins(let c): return "\(c) coins"
        case .supporterPack: return "Supporter Pack"
        case .free: return "Raise"
        }
    }

    private func tap() {
        if owned {
            Feedback.select()
            game.profile.equippedBanner = banner.id
            game.save()
            return
        }
        if case .coins(let cost) = banner.price {
            guard game.profile.coins >= cost else {
                Feedback.error()
                game.showToast("Earn more coins in battle")
                return
            }
            game.profile.coins -= cost
            game.profile.ownedCosmetics.append(banner.id)
            game.profile.equippedBanner = banner.id
            SoundEngine.shared.play(.coin)
            Haptics.success()
            game.save()
        }
    }
}
