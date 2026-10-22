import SwiftUI
import UIKit

/// Purely cosmetic outpost banners. Nothing here changes combat.
enum Cosmetics {
    struct Banner: Identifiable, Equatable {
        enum Price: Equatable {
            case free
            case coins(Int)
            case supporterPack
        }

        var id: String
        var name: String
        var color: UIColor
        var price: Price

        var swiftUIColor: Color { Color(color) }
    }

    static let banners: [Banner] = [
        Banner(id: "copper", name: "Copper Standard", color: UIPalette.copper, price: .free),
        Banner(id: "forest", name: "Greenwood Pennant", color: UIColor(hex: 0x4F8A5B), price: .coins(150)),
        Banner(id: "slate", name: "Stormwatch Blue", color: UIColor(hex: 0x4D74A8), price: .coins(250)),
        Banner(id: "crimson", name: "Ember Crimson", color: UIColor(hex: 0xB8433A), price: .coins(350)),
        Banner(id: "royal", name: "Royal Violet", color: UIColor(hex: 0x7D5BA6), price: .coins(500)),
        Banner(id: "sunburst", name: "Supporter Sunburst", color: UIPalette.gold, price: .supporterPack),
    ]

    static func banner(id: String) -> Banner {
        banners.first { $0.id == id } ?? banners[0]
    }
}
