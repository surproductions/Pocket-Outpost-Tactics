import SwiftUI
import GameCore

/// Chunky tabletop-style button: a raised face over a darker base that presses down.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Palette.copper
    var textColor: Color = Palette.cream
    var height: CGFloat = 56
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(GameFont.heading(height > 50 ? 20 : 16))
            .foregroundStyle(textColor)
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1.5)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Palette.ink.opacity(0.55), lineWidth: 2)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.ink.opacity(0.75))
                    .offset(y: pressed ? 1 : 5)
            )
            .offset(y: pressed ? 4 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
            .contentShape(Rectangle())
    }
}

/// Parchment card used for panels and sheets.
struct ParchmentPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.cream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Palette.parchmentShadow, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            )
    }
}

/// Copper ribbon banner for screen titles.
struct RibbonTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(GameFont.title(22))
            .foregroundStyle(Palette.cream)
            .shadow(color: Palette.ink.opacity(0.5), radius: 0, y: 2)
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .background(
                RibbonShape()
                    .fill(Palette.copper)
                    .overlay(RibbonShape().stroke(Palette.ink.opacity(0.6), lineWidth: 2))
            )
            .accessibilityAddTraits(.isHeader)
    }
}

struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let notch: CGFloat = 12
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

enum ResourceKind {
    case coins, supplies, timber, xp

    var symbol: String {
        switch self {
        case .coins: return "circle.circle.fill"
        case .supplies: return "shippingbox.fill"
        case .timber: return "tree.fill"
        case .xp: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .coins: return Palette.gold
        case .supplies: return Palette.copper
        case .timber: return Palette.forest
        case .xp: return Palette.slate
        }
    }

    var name: String {
        switch self {
        case .coins: return "Coins"
        case .supplies: return "Supplies"
        case .timber: return "Timber"
        case .xp: return "Experience"
        }
    }
}

struct ResourceChip: View {
    var kind: ResourceKind
    var amount: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(kind.color)
                .shadow(color: .black.opacity(0.3), radius: 0, y: 1)
            Text("\(amount)")
                .font(GameFont.heading(15))
                .foregroundStyle(Palette.cream)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Palette.ink.opacity(0.78)))
        .overlay(Capsule().strokeBorder(Palette.cream.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) \(kind.name)")
    }
}

struct ResourceBar: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        HStack(spacing: 6) {
            ResourceChip(kind: .coins, amount: game.profile.coins)
            ResourceChip(kind: .supplies, amount: game.profile.supplies)
            ResourceChip(kind: .timber, amount: game.profile.timber)
        }
        .animation(.easeOut(duration: 0.4), value: game.profile.supplies)
    }
}

struct RewardRow: View {
    var reward: Reward

    var body: some View {
        HStack(spacing: 8) {
            if reward.coins > 0 { ResourceChip(kind: .coins, amount: reward.coins) }
            if reward.supplies > 0 { ResourceChip(kind: .supplies, amount: reward.supplies) }
            if reward.timber > 0 { ResourceChip(kind: .timber, amount: reward.timber) }
            if reward.xp > 0 { ResourceChip(kind: .xp, amount: reward.xp) }
        }
    }
}

struct StarRow: View {
    var stars: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < stars ? Palette.gold : Palette.ink.opacity(0.3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) of 3 stars")
    }
}

/// Square icon button with a large (48pt) touch target.
struct IconButton: View {
    var systemName: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Palette.cream)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Palette.ink.opacity(0.8)))
                .overlay(Circle().strokeBorder(Palette.cream.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct StatPill: View {
    var icon: String
    var value: String
    var label: String
    var tint: Color = Palette.ink

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(value).font(GameFont.heading(13)).monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// The parchment-and-pine backdrop used behind menus.
struct MenuBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2E4A44), Palette.night], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // Distant pine silhouettes
                for layer in 0..<2 {
                    let base = size.height * (layer == 0 ? 0.78 : 0.9)
                    let color = layer == 0 ? Color(hex: 0x2B4038) : Color(hex: 0x1E2E2A)
                    var x: CGFloat = -20
                    var seed: UInt64 = layer == 0 ? 7 : 13
                    while x < size.width + 20 {
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        let h = CGFloat(40 + Int(seed >> 59) * 6) * (layer == 0 ? 1 : 1.3)
                        var tree = Path()
                        tree.move(to: CGPoint(x: x, y: base - h))
                        tree.addLine(to: CGPoint(x: x + h * 0.32, y: base))
                        tree.addLine(to: CGPoint(x: x - h * 0.32, y: base))
                        tree.closeSubpath()
                        ctx.fill(tree, with: .color(color))
                        x += h * 0.45
                    }
                    ctx.fill(Path(CGRect(x: 0, y: base, width: size.width, height: size.height - base)), with: .color(color))
                }
                // Stars
                var s: UInt64 = 42
                for _ in 0..<40 {
                    s = s &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(s % 1000) / 1000 * size.width
                    let y = CGFloat((s >> 20) % 1000) / 1000 * size.height * 0.45
                    let r = CGFloat((s >> 40) % 3) * 0.6 + 0.8
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.55)))
                }
            }
        }
        .ignoresSafeArea()
    }
}
