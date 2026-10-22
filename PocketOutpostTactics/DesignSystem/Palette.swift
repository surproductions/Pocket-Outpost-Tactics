import SwiftUI
import UIKit

/// Brand palette from the art brief.
enum Palette {
    static let forest = Color(hex: 0x63876A)
    static let sand = Color(hex: 0xE8CE9C)
    static let slate = Color(hex: 0x617C98)
    static let copper = Color(hex: 0xD58B56)
    static let cream = Color(hex: 0xFFF2DB)
    static let ink = Color(hex: 0x26323B)
    static let gold = Color(hex: 0xF3C86B)

    static let danger = Color(hex: 0xC9583E)
    static let moveBlue = Color(hex: 0x5FA8E8)
    static let heal = Color(hex: 0x7CC47F)
    static let night = Color(hex: 0x1C2630)
    static let parchmentShadow = Color(hex: 0xC9A97A)
}

enum UIPalette {
    static let forest = UIColor(hex: 0x63876A)
    static let sand = UIColor(hex: 0xE8CE9C)
    static let slate = UIColor(hex: 0x617C98)
    static let copper = UIColor(hex: 0xD58B56)
    static let cream = UIColor(hex: 0xFFF2DB)
    static let ink = UIColor(hex: 0x26323B)
    static let gold = UIColor(hex: 0xF3C86B)
    static let danger = UIColor(hex: 0xC9583E)
    static let moveBlue = UIColor(hex: 0x5FA8E8)
    static let heal = UIColor(hex: 0x7CC47F)
    static let night = UIColor(hex: 0x1C2630)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    func adjusted(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, min(1, b + amount)), alpha: a)
    }
}

enum GameFont {
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}
