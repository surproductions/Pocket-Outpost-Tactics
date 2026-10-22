import UIKit
import SpriteKit
import GameCore

/// All game art is drawn procedurally with Core Graphics, so every asset is original and scales
/// crisply on every iPhone. Textures are cached after first use.
enum Art {
    private static var textureCache: [String: SKTexture] = [:]
    private static var imageCache: [String: UIImage] = [:]

    static func cachedImage(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> UIImage {
        if let img = imageCache[key] { return img }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(ctx.cgContext, size)
        }
        imageCache[key] = img
        return img
    }

    static func cachedTexture(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = textureCache[key] { return t }
        let t = SKTexture(image: cachedImage(key, size: size, draw: draw))
        textureCache[key] = t
        return t
    }

    static let ink = UIPalette.ink
    static let skin = UIColor(hex: 0xF4CDA5)
    static let skinShade = UIColor(hex: 0xE2AE85)

    // MARK: Helpers

    static func fill(_ ctx: CGContext, _ path: CGPath, _ color: UIColor, stroke: CGFloat = 1.6) {
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        if stroke > 0 {
            ctx.addPath(path)
            ctx.setStrokeColor(ink.cgColor)
            ctx.setLineWidth(stroke)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        }
    }

    static func rounded(_ rect: CGRect, _ r: CGFloat) -> CGPath {
        UIBezierPath(roundedRect: rect, cornerRadius: r).cgPath
    }

    static func oval(_ rect: CGRect) -> CGPath {
        CGPath(ellipseIn: rect, transform: nil)
    }

    static func poly(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: points)
        p.closeSubpath()
        return p
    }

    static func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ color: UIColor, _ width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }
}

// MARK: - Units

extension Art {
    static let unitCanvas = CGSize(width: 72, height: 88)

    static func unitTexture(_ kind: UnitClass) -> SKTexture {
        cachedTexture("unit-\(kind.rawValue)", size: unitCanvas) { ctx, size in
            drawUnit(kind, in: ctx, size: size)
        }
    }

    static func unitImage(_ kind: UnitClass) -> UIImage {
        cachedImage("unit-\(kind.rawValue)", size: unitCanvas) { ctx, size in
            drawUnit(kind, in: ctx, size: size)
        }
    }

    private struct Look {
        var body: UIColor
        var bodyTrim: UIColor
        var boots: UIColor
        var scale: CGFloat = 1
        var angry = false
    }

    private static func look(for kind: UnitClass) -> Look {
        switch kind {
        case .guardian: return Look(body: UIColor(hex: 0xA9B6C3), bodyTrim: UIColor(hex: 0x617C98), boots: UIColor(hex: 0x4A5563))
        case .ranger: return Look(body: UIColor(hex: 0x5E8A5A), bodyTrim: UIColor(hex: 0x3F5F3E), boots: UIColor(hex: 0x6B4A33))
        case .scout: return Look(body: UIColor(hex: 0xD7B07A), bodyTrim: UIColor(hex: 0xD58B56), boots: UIColor(hex: 0x7A5A3C))
        case .engineer: return Look(body: UIColor(hex: 0x8C6A4C), bodyTrim: UIColor(hex: 0xFFF2DB), boots: UIColor(hex: 0x4E3B2C))
        case .raider: return Look(body: UIColor(hex: 0x9A5040), bodyTrim: UIColor(hex: 0x5B3A2E), boots: UIColor(hex: 0x3D2C25), angry: true)
        case .archer: return Look(body: UIColor(hex: 0x7A4258), bodyTrim: UIColor(hex: 0x4A2A38), boots: UIColor(hex: 0x3D2C25), angry: true)
        case .brute: return Look(body: UIColor(hex: 0x5E646C), bodyTrim: UIColor(hex: 0x8E4A3A), boots: UIColor(hex: 0x2F3439), scale: 1.14, angry: true)
        case .warlord: return Look(body: UIColor(hex: 0x4B3A3A), bodyTrim: UIColor(hex: 0xF3C86B), boots: UIColor(hex: 0x2A2020), scale: 1.2, angry: true)
        }
    }

    static func drawUnit(_ kind: UnitClass, in ctx: CGContext, size: CGSize) {
        let l = look(for: kind)
        ctx.saveGState()
        // Feet sit at the bottom centre; scale big units from there.
        ctx.translateBy(x: size.width / 2, y: size.height - 4)
        ctx.scaleBy(x: l.scale, y: l.scale)
        ctx.translateBy(x: -30, y: -74)

        // Behind-body accessories
        switch kind {
        case .ranger, .archer:
            fill(ctx, rounded(CGRect(x: 36, y: 34, width: 9, height: 22), 3), UIColor(hex: 0x7A5233))
            for i in 0..<3 {
                fill(ctx, poly([CGPoint(x: 37 + CGFloat(i) * 3, y: 34), CGPoint(x: 39 + CGFloat(i) * 3, y: 27), CGPoint(x: 41 + CGFloat(i) * 3, y: 34)]),
                     kind == .ranger ? UIPalette.cream : UIColor(hex: 0x2E2E2E), stroke: 1)
            }
        case .warlord:
            fill(ctx, poly([CGPoint(x: 14, y: 38), CGPoint(x: 46, y: 38), CGPoint(x: 52, y: 70), CGPoint(x: 8, y: 70)]), UIColor(hex: 0xA3302B))
        case .scout:
            // Flowing scarf tail
            fill(ctx, poly([CGPoint(x: 38, y: 38), CGPoint(x: 54, y: 44), CGPoint(x: 50, y: 50), CGPoint(x: 36, y: 44)]), UIPalette.copper)
        default: break
        }

        // Legs
        fill(ctx, rounded(CGRect(x: 21, y: 58, width: 8, height: 14), 3), l.boots)
        fill(ctx, rounded(CGRect(x: 31, y: 58, width: 8, height: 14), 3), l.boots)

        // Body
        let bodyRect = CGRect(x: 15, y: 37, width: 30, height: 26)
        fill(ctx, rounded(bodyRect, 9), l.body)
        switch kind {
        case .guardian:
            fill(ctx, rounded(CGRect(x: 21, y: 40, width: 18, height: 14), 5), UIColor(hex: 0xD3DCE4), stroke: 1.2)
        case .engineer:
            fill(ctx, rounded(CGRect(x: 20, y: 44, width: 20, height: 18), 4), l.bodyTrim, stroke: 1.2)
            fill(ctx, rounded(CGRect(x: 26, y: 50, width: 8, height: 6), 2), UIColor(hex: 0xC9A97A), stroke: 1)
        case .ranger, .archer:
            fill(ctx, poly([CGPoint(x: 15, y: 42), CGPoint(x: 30, y: 60), CGPoint(x: 45, y: 42), CGPoint(x: 45, y: 63), CGPoint(x: 15, y: 63)]), l.bodyTrim, stroke: 1.2)
        case .brute, .warlord:
            fill(ctx, oval(CGRect(x: 9, y: 34, width: 15, height: 11)), l.bodyTrim)
            fill(ctx, oval(CGRect(x: 36, y: 34, width: 15, height: 11)), l.bodyTrim)
        default: break
        }
        // Belt
        fill(ctx, rounded(CGRect(x: 15, y: 53, width: 30, height: 4), 1.5), UIColor(hex: 0x5B3E2B), stroke: 1)
        fill(ctx, rounded(CGRect(x: 27.5, y: 52.5, width: 5, height: 5), 1), UIPalette.gold, stroke: 0.8)

        // Arms
        fill(ctx, oval(CGRect(x: 9, y: 42, width: 10, height: 10)), kind == .guardian ? UIColor(hex: 0xD3DCE4) : skin)
        fill(ctx, oval(CGRect(x: 41, y: 42, width: 10, height: 10)), kind == .guardian ? UIColor(hex: 0xD3DCE4) : skin)

        // Head
        let head = CGRect(x: 13, y: 6, width: 34, height: 33)
        fill(ctx, oval(head), skin)

        // Hair / headgear (back layer)
        switch kind {
        case .raider:
            fill(ctx, poly([CGPoint(x: 18, y: 12), CGPoint(x: 24, y: 1), CGPoint(x: 30, y: 9), CGPoint(x: 36, y: 0), CGPoint(x: 42, y: 12)]), UIColor(hex: 0x3B2A22))
        default: break
        }

        // Face
        let eyeY: CGFloat = 24
        ctx.setFillColor(ink.cgColor)
        ctx.fillEllipse(in: CGRect(x: 22, y: eyeY, width: 4, height: 5.5))
        ctx.fillEllipse(in: CGRect(x: 34, y: eyeY, width: 4, height: 5.5))
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: 23, y: eyeY + 0.8, width: 1.6, height: 1.6))
        ctx.fillEllipse(in: CGRect(x: 35, y: eyeY + 0.8, width: 1.6, height: 1.6))
        if l.angry {
            line(ctx, CGPoint(x: 20, y: eyeY - 3), CGPoint(x: 27, y: eyeY - 1), ink, 1.8)
            line(ctx, CGPoint(x: 40, y: eyeY - 3), CGPoint(x: 33, y: eyeY - 1), ink, 1.8)
        } else {
            ctx.setFillColor(UIColor(hex: 0xF29C8F, alpha: 0.7).cgColor)
            ctx.fillEllipse(in: CGRect(x: 17, y: 30, width: 6, height: 3.5))
            ctx.fillEllipse(in: CGRect(x: 37, y: 30, width: 6, height: 3.5))
        }
        // Mouth
        ctx.setStrokeColor(ink.cgColor)
        ctx.setLineWidth(1.3)
        if l.angry {
            ctx.move(to: CGPoint(x: 27, y: 33)); ctx.addLine(to: CGPoint(x: 33, y: 33))
        } else {
            ctx.addArc(center: CGPoint(x: 30, y: 31), radius: 2.6, startAngle: 0.3, endAngle: .pi - 0.3, clockwise: false)
        }
        ctx.strokePath()

        // Headgear (front layer)
        switch kind {
        case .guardian:
            let helm = CGMutablePath()
            helm.addArc(center: CGPoint(x: 30, y: 22), radius: 17.5, startAngle: .pi, endAngle: 0, clockwise: false)
            helm.addLine(to: CGPoint(x: 47.5, y: 25))
            helm.addLine(to: CGPoint(x: 12.5, y: 25))
            helm.closeSubpath()
            fill(ctx, helm, UIColor(hex: 0xBAC6D1))
            fill(ctx, rounded(CGRect(x: 27, y: 4, width: 6, height: 20), 2), UIColor(hex: 0x8E9BA8), stroke: 1)
            fill(ctx, poly([CGPoint(x: 28, y: 4), CGPoint(x: 38, y: -3), CGPoint(x: 34, y: 6)]), UIPalette.copper, stroke: 1.2)
        case .ranger, .archer:
            let hood = CGMutablePath()
            hood.addArc(center: CGPoint(x: 30, y: 22), radius: 18.5, startAngle: .pi * 0.92, endAngle: .pi * 0.08, clockwise: false)
            hood.addQuadCurve(to: CGPoint(x: 30, y: 13), control: CGPoint(x: 42, y: 12))
            hood.addQuadCurve(to: CGPoint(x: 12.5, y: 27), control: CGPoint(x: 18, y: 12))
            hood.closeSubpath()
            fill(ctx, hood, kind == .ranger ? UIColor(hex: 0x4F7A4C) : UIColor(hex: 0x5A2F42))
            fill(ctx, poly([CGPoint(x: 24, y: 6), CGPoint(x: 30, y: -2), CGPoint(x: 36, y: 6)]), kind == .ranger ? UIColor(hex: 0x4F7A4C) : UIColor(hex: 0x5A2F42), stroke: 1.2)
        case .scout:
            fill(ctx, poly([CGPoint(x: 12.5, y: 18), CGPoint(x: 30, y: 8), CGPoint(x: 47.5, y: 18), CGPoint(x: 47, y: 21), CGPoint(x: 13, y: 21)]), UIPalette.copper)
            fill(ctx, poly([CGPoint(x: 46, y: 18), CGPoint(x: 55, y: 14), CGPoint(x: 53, y: 22)]), UIPalette.copper, stroke: 1.2)
            fill(ctx, poly([CGPoint(x: 16, y: 13), CGPoint(x: 26, y: 5), CGPoint(x: 34, y: 9), CGPoint(x: 20, y: 15)]), UIColor(hex: 0x6B4A33), stroke: 1)
        case .engineer:
            fill(ctx, poly([CGPoint(x: 13, y: 16), CGPoint(x: 18, y: 6), CGPoint(x: 42, y: 6), CGPoint(x: 47, y: 16)]), UIColor(hex: 0xC27A44))
            fill(ctx, rounded(CGRect(x: 11, y: 14, width: 38, height: 4), 2), UIColor(hex: 0x9C5E33), stroke: 1)
            fill(ctx, oval(CGRect(x: 19, y: 14, width: 9, height: 8)), UIPalette.slate, stroke: 1.2)
            fill(ctx, oval(CGRect(x: 32, y: 14, width: 9, height: 8)), UIPalette.slate, stroke: 1.2)
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            ctx.fillEllipse(in: CGRect(x: 21, y: 15.5, width: 3, height: 3))
            ctx.fillEllipse(in: CGRect(x: 34, y: 15.5, width: 3, height: 3))
        case .raider:
            fill(ctx, poly([CGPoint(x: 13, y: 17), CGPoint(x: 47, y: 17), CGPoint(x: 46, y: 21), CGPoint(x: 14, y: 21)]), UIColor(hex: 0xB33A2E), stroke: 1.2)
            fill(ctx, poly([CGPoint(x: 20, y: 32), CGPoint(x: 40, y: 32), CGPoint(x: 36, y: 41), CGPoint(x: 24, y: 41)]), UIColor(hex: 0x3B2A22), stroke: 1.2)
        case .brute, .warlord:
            let helm = CGMutablePath()
            helm.addArc(center: CGPoint(x: 30, y: 22), radius: 17.5, startAngle: .pi, endAngle: 0, clockwise: false)
            helm.addLine(to: CGPoint(x: 47.5, y: 23))
            helm.addLine(to: CGPoint(x: 12.5, y: 23))
            helm.closeSubpath()
            fill(ctx, helm, kind == .warlord ? UIColor(hex: 0x3A3030) : UIColor(hex: 0x6E757E))
            let horn = UIColor(hex: 0xEDE3CF)
            fill(ctx, poly([CGPoint(x: 13, y: 14), CGPoint(x: 2, y: 2), CGPoint(x: 16, y: 9)]), horn, stroke: 1.2)
            fill(ctx, poly([CGPoint(x: 47, y: 14), CGPoint(x: 58, y: 2), CGPoint(x: 44, y: 9)]), horn, stroke: 1.2)
            if kind == .warlord {
                fill(ctx, poly([CGPoint(x: 20, y: 6), CGPoint(x: 23, y: -2), CGPoint(x: 27, y: 4), CGPoint(x: 30, y: -4), CGPoint(x: 33, y: 4), CGPoint(x: 37, y: -2), CGPoint(x: 40, y: 6)]), UIPalette.gold, stroke: 1.2)
            }
            fill(ctx, poly([CGPoint(x: 20, y: 33), CGPoint(x: 40, y: 33), CGPoint(x: 34, y: 42), CGPoint(x: 26, y: 42)]), UIColor(hex: 0x2E2420), stroke: 1.2)
        }

        // Weapons / gear in front
        switch kind {
        case .guardian:
            line(ctx, CGPoint(x: 50, y: 50), CGPoint(x: 50, y: 22), ink, 4.5)
            line(ctx, CGPoint(x: 50, y: 49), CGPoint(x: 50, y: 23), UIColor(hex: 0xE8EEF3), 2.8)
            line(ctx, CGPoint(x: 45, y: 49), CGPoint(x: 55, y: 49), UIColor(hex: 0x6B4A33), 3.5)
            let shield = CGMutablePath()
            shield.move(to: CGPoint(x: 3, y: 38))
            shield.addLine(to: CGPoint(x: 23, y: 38))
            shield.addQuadCurve(to: CGPoint(x: 13, y: 66), control: CGPoint(x: 24, y: 58))
            shield.addQuadCurve(to: CGPoint(x: 3, y: 38), control: CGPoint(x: 2, y: 58))
            shield.closeSubpath()
            fill(ctx, shield, UIPalette.slate, stroke: 1.8)
            fill(ctx, poly([CGPoint(x: 13, y: 43), CGPoint(x: 18, y: 50), CGPoint(x: 13, y: 58), CGPoint(x: 8, y: 50)]), UIPalette.gold, stroke: 1)
        case .ranger, .archer:
            ctx.setStrokeColor(ink.cgColor)
            ctx.setLineWidth(4.5)
            ctx.addArc(center: CGPoint(x: 44, y: 46), radius: 16, startAngle: -.pi / 2.3, endAngle: .pi / 2.3, clockwise: false)
            ctx.strokePath()
            ctx.setStrokeColor(UIColor(hex: 0x9C6B3F).cgColor)
            ctx.setLineWidth(2.6)
            ctx.addArc(center: CGPoint(x: 44, y: 46), radius: 16, startAngle: -.pi / 2.3, endAngle: .pi / 2.3, clockwise: false)
            ctx.strokePath()
            line(ctx, CGPoint(x: 47.5, y: 31.5), CGPoint(x: 47.5, y: 60.5), UIPalette.cream, 1)
        case .scout:
            line(ctx, CGPoint(x: 47, y: 52), CGPoint(x: 54, y: 38), ink, 4)
            line(ctx, CGPoint(x: 47, y: 52), CGPoint(x: 54, y: 38), UIColor(hex: 0xE8EEF3), 2.2)
            line(ctx, CGPoint(x: 44, y: 51), CGPoint(x: 50, y: 54), UIColor(hex: 0x6B4A33), 3)
        case .engineer:
            line(ctx, CGPoint(x: 47, y: 56), CGPoint(x: 52, y: 32), ink, 4.5)
            line(ctx, CGPoint(x: 47, y: 56), CGPoint(x: 52, y: 32), UIColor(hex: 0x9C6B3F), 2.6)
            fill(ctx, rounded(CGRect(x: 44, y: 26, width: 16, height: 8), 2), UIColor(hex: 0x8E9BA8))
        case .raider:
            line(ctx, CGPoint(x: 48, y: 58), CGPoint(x: 50, y: 28), ink, 4.5)
            line(ctx, CGPoint(x: 48, y: 58), CGPoint(x: 50, y: 28), UIColor(hex: 0x7A5233), 2.6)
            fill(ctx, poly([CGPoint(x: 49, y: 28), CGPoint(x: 60, y: 24), CGPoint(x: 61, y: 38), CGPoint(x: 50, y: 36)]), UIColor(hex: 0xC5CDD4))
        case .brute:
            line(ctx, CGPoint(x: 46, y: 60), CGPoint(x: 52, y: 26), ink, 5)
            line(ctx, CGPoint(x: 46, y: 60), CGPoint(x: 52, y: 26), UIColor(hex: 0x7A5233), 3)
            fill(ctx, oval(CGRect(x: 44, y: 14, width: 17, height: 19)), UIColor(hex: 0x8A6243))
            for (x, y) in [(46.0, 16.0), (57.0, 18.0), (52.0, 13.0)] {
                fill(ctx, poly([CGPoint(x: x, y: y), CGPoint(x: x + 2, y: y - 4), CGPoint(x: x + 4, y: y)]), UIColor(hex: 0xC5CDD4), stroke: 0.8)
            }
        case .warlord:
            line(ctx, CGPoint(x: 47, y: 64), CGPoint(x: 51, y: 14), ink, 5)
            line(ctx, CGPoint(x: 47, y: 64), CGPoint(x: 51, y: 14), UIColor(hex: 0x5B3E2B), 3)
            let blade = CGMutablePath()
            blade.move(to: CGPoint(x: 51, y: 16))
            blade.addQuadCurve(to: CGPoint(x: 52, y: 38), control: CGPoint(x: 68, y: 26))
            blade.addLine(to: CGPoint(x: 50, y: 30))
            blade.closeSubpath()
            fill(ctx, blade, UIColor(hex: 0xD9DEE3))
            line(ctx, CGPoint(x: 53, y: 20), CGPoint(x: 55, y: 34), UIPalette.gold, 1.5)
        }
        ctx.restoreGState()
    }
}

// MARK: - Tiles and props

extension Art {
    static func groundColor(_ terrain: Terrain, biome: Biome) -> UIColor {
        switch terrain {
        case .water: return UIColor(hex: 0x6FB3D2)
        case .snow: return UIColor(hex: 0xF2F6FA)
        case .ruins: return UIColor(hex: 0xBFB3A2)
        case .highGround:
            switch biome {
            case .canyon: return UIColor(hex: 0xE2B98A)
            case .snow: return UIColor(hex: 0xDCE6EE)
            default: return UIColor(hex: 0x9CBF7E)
            }
        case .path:
            switch biome {
            case .snow: return UIColor(hex: 0xD9D3C7)
            default: return UIColor(hex: 0xE3CB98)
            }
        case .grass, .forest, .rock:
            switch biome {
            case .forest: return terrain == .forest ? UIColor(hex: 0x6E9A62) : UIColor(hex: 0x86B26F)
            case .canyon: return UIColor(hex: 0xE8CE9C)
            case .snow: return UIColor(hex: 0xE6EDF2)
            case .ruins: return UIColor(hex: 0xA8A58A)
            }
        }
    }

    static func sideColor(_ biome: Biome) -> UIColor {
        switch biome {
        case .forest: return UIColor(hex: 0x7A5A3E)
        case .canyon: return UIColor(hex: 0xB0683F)
        case .snow: return UIColor(hex: 0x8C9BA8)
        case .ruins: return UIColor(hex: 0x6E625A)
        }
    }

    /// A tabletop tile: rounded top face plus a short earthen side, like a diorama block.
    static func tileTexture(_ terrain: Terrain, biome: Biome, variant: Int, size: CGSize, depth: CGFloat) -> SKTexture {
        let raise: CGFloat = terrain == .highGround ? 6 : 0
        let total = CGSize(width: size.width, height: size.height + depth + raise)
        let key = "tile-\(terrain.rawValue)-\(biome.rawValue)-\(variant)-\(Int(size.width))x\(Int(size.height))"
        return cachedTexture(key, size: total) { ctx, _ in
            let top = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            var base = groundColor(terrain, biome: biome)
            if variant % 2 == 1 { base = base.adjusted(by: -0.035) }
            // Side
            let side = CGRect(x: 1, y: top.midY, width: top.width, height: top.height / 2 + depth + raise)
            fill(ctx, rounded(side, 7), sideColor(biome).adjusted(by: terrain == .highGround ? 0.05 : 0), stroke: 0)
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.12).cgColor)
            ctx.fill(CGRect(x: 1, y: top.maxY + raise, width: top.width, height: 2))
            // Top
            if terrain == .water {
                fill(ctx, rounded(top.offsetBy(dx: 0, dy: 3), 7), base.adjusted(by: -0.1), stroke: 0)
                fill(ctx, rounded(top.insetBy(dx: 2, dy: 2).offsetBy(dx: 0, dy: 3), 6), base, stroke: 0)
                ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.55).cgColor)
                ctx.setLineWidth(1.5)
                for i in 0..<3 {
                    let y = top.minY + 10 + CGFloat(i) * 9 + CGFloat(variant % 3)
                    let x = top.minX + 8 + CGFloat((i * 13 + variant * 7) % 18)
                    ctx.move(to: CGPoint(x: x, y: y))
                    ctx.addQuadCurve(to: CGPoint(x: x + 12, y: y), control: CGPoint(x: x + 6, y: y - 3))
                }
                ctx.strokePath()
                return
            }
            fill(ctx, rounded(top, 7), base, stroke: 0)
            // Soft highlight on the top edge for a lit-from-above look
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.13).cgColor)
            ctx.addPath(rounded(CGRect(x: top.minX, y: top.minY, width: top.width, height: top.height * 0.4), 7))
            ctx.fillPath()
            // Speckle details
            var seed = UInt64(variant &* 2654435761 &+ terrain.rawValue.count)
            func rnd() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 40) / CGFloat(1 << 24)
            }
            let detail: UIColor
            switch (terrain, biome) {
            case (.snow, _), (_, .snow): detail = UIColor(hex: 0xC9D6E0)
            case (.ruins, _): detail = UIColor(hex: 0x8F8475)
            case (.path, _), (_, .canyon): detail = UIColor(hex: 0xC9A97A)
            default: detail = UIColor(hex: 0x5F8A52)
            }
            for _ in 0..<5 {
                let x = top.minX + 6 + rnd() * (top.width - 12)
                let y = top.minY + 6 + rnd() * (top.height - 12)
                if biome == .forest && terrain != .path && terrain != .ruins {
                    line(ctx, CGPoint(x: x, y: y), CGPoint(x: x - 1.5, y: y - 4), detail, 1.4)
                    line(ctx, CGPoint(x: x + 2, y: y), CGPoint(x: x + 3, y: y - 3.5), detail, 1.4)
                } else {
                    ctx.setFillColor(detail.withAlphaComponent(0.6).cgColor)
                    ctx.fillEllipse(in: CGRect(x: x, y: y, width: 3, height: 2))
                }
            }
            if terrain == .ruins {
                ctx.setStrokeColor(UIColor(hex: 0x8F8475).cgColor)
                ctx.setLineWidth(1)
                ctx.move(to: CGPoint(x: top.midX, y: top.minY + 3)); ctx.addLine(to: CGPoint(x: top.midX, y: top.maxY - 3))
                ctx.move(to: CGPoint(x: top.minX + 3, y: top.midY)); ctx.addLine(to: CGPoint(x: top.maxX - 3, y: top.midY))
                ctx.strokePath()
            }
        }
    }

    static func pineTexture(snowy: Bool) -> SKTexture {
        cachedTexture("pine-\(snowy)", size: CGSize(width: 34, height: 52)) { ctx, _ in
            fill(ctx, rounded(CGRect(x: 14, y: 40, width: 6, height: 10), 2), UIColor(hex: 0x6B4A33), stroke: 1.2)
            let green = snowy ? UIColor(hex: 0x4E7363) : UIColor(hex: 0x3F6B45)
            for (i, w) in [CGFloat(30), 24, 17].enumerated() {
                let y = 42 - CGFloat(i) * 12
                fill(ctx, poly([CGPoint(x: 17 - w / 2, y: y), CGPoint(x: 17, y: y - 18), CGPoint(x: 17 + w / 2, y: y)]),
                     green.adjusted(by: CGFloat(i) * 0.04), stroke: 1.4)
                if snowy {
                    fill(ctx, poly([CGPoint(x: 17 - w / 4, y: y - 9), CGPoint(x: 17, y: y - 18), CGPoint(x: 17 + w / 4, y: y - 9)]), .white, stroke: 0)
                }
            }
        }
    }

    static func cactusTexture() -> SKTexture {
        cachedTexture("cactus", size: CGSize(width: 30, height: 44)) { ctx, _ in
            let green = UIColor(hex: 0x5E9A4E)
            fill(ctx, rounded(CGRect(x: 11, y: 6, width: 9, height: 36), 4.5), green)
            fill(ctx, rounded(CGRect(x: 3, y: 16, width: 7, height: 14), 3.5), green)
            fill(ctx, rounded(CGRect(x: 21, y: 12, width: 7, height: 14), 3.5), green)
            fill(ctx, oval(CGRect(x: 12, y: 2, width: 7, height: 6)), UIColor(hex: 0xE79AD0), stroke: 1)
        }
    }

    static func boulderTexture(biome: Biome) -> SKTexture {
        cachedTexture("boulder-\(biome.rawValue)", size: CGSize(width: 46, height: 36)) { ctx, _ in
            let base: UIColor
            switch biome {
            case .canyon: base = UIColor(hex: 0xC77B4E)
            case .snow: base = UIColor(hex: 0x9AA8B4)
            case .ruins: base = UIColor(hex: 0x857B70)
            case .forest: base = UIColor(hex: 0xA3A7A6)
            }
            fill(ctx, poly([CGPoint(x: 4, y: 32), CGPoint(x: 8, y: 14), CGPoint(x: 20, y: 5), CGPoint(x: 34, y: 8), CGPoint(x: 43, y: 20), CGPoint(x: 41, y: 32)]), base, stroke: 1.8)
            fill(ctx, poly([CGPoint(x: 10, y: 15), CGPoint(x: 20, y: 7), CGPoint(x: 30, y: 10), CGPoint(x: 22, y: 18)]), base.adjusted(by: 0.12), stroke: 0)
            if biome == .snow {
                fill(ctx, poly([CGPoint(x: 9, y: 14), CGPoint(x: 20, y: 5), CGPoint(x: 34, y: 8), CGPoint(x: 28, y: 13), CGPoint(x: 16, y: 13)]), .white, stroke: 0)
            }
        }
    }

    static func columnTexture() -> SKTexture {
        cachedTexture("column", size: CGSize(width: 28, height: 46)) { ctx, _ in
            let stone = UIColor(hex: 0xCFC4B4)
            fill(ctx, rounded(CGRect(x: 4, y: 38, width: 20, height: 6), 2), stone.adjusted(by: -0.1))
            fill(ctx, poly([CGPoint(x: 7, y: 39), CGPoint(x: 7, y: 12), CGPoint(x: 12, y: 6), CGPoint(x: 16, y: 14), CGPoint(x: 21, y: 9), CGPoint(x: 21, y: 39)]), stone)
            line(ctx, CGPoint(x: 12, y: 16), CGPoint(x: 12, y: 37), stone.adjusted(by: -0.15), 1.2)
            line(ctx, CGPoint(x: 16, y: 18), CGPoint(x: 16, y: 37), stone.adjusted(by: -0.15), 1.2)
            fill(ctx, oval(CGRect(x: 15, y: 30, width: 6, height: 4)), UIColor(hex: 0xE07A3A, alpha: 0.85), stroke: 0)
        }
    }

    static func barricadeTexture() -> SKTexture {
        cachedTexture("barricade", size: CGSize(width: 50, height: 40)) { ctx, _ in
            let wood = UIColor(hex: 0xC9974F)
            for i in 0..<5 {
                let x = 5 + CGFloat(i) * 8.5
                let h: CGFloat = i % 2 == 0 ? 30 : 26
                fill(ctx, poly([CGPoint(x: x, y: 38), CGPoint(x: x, y: 38 - h + 6), CGPoint(x: x + 3.5, y: 38 - h), CGPoint(x: x + 7, y: 38 - h + 6), CGPoint(x: x + 7, y: 38)]), wood.adjusted(by: CGFloat(i % 2) * -0.06))
            }
            line(ctx, CGPoint(x: 3, y: 24), CGPoint(x: 47, y: 26), ink, 3.5)
            line(ctx, CGPoint(x: 3, y: 24), CGPoint(x: 47, y: 26), UIColor(hex: 0xE8D7AE), 2)
        }
    }

    static func gateTexture() -> SKTexture {
        cachedTexture("gate", size: CGSize(width: 62, height: 66)) { ctx, _ in
            let wood = UIColor(hex: 0xA8743F)
            fill(ctx, rounded(CGRect(x: 3, y: 14, width: 12, height: 50), 3), wood.adjusted(by: -0.08))
            fill(ctx, rounded(CGRect(x: 47, y: 14, width: 12, height: 50), 3), wood.adjusted(by: -0.08))
            fill(ctx, poly([CGPoint(x: 1, y: 16), CGPoint(x: 9, y: 4), CGPoint(x: 17, y: 16)]), UIPalette.copper)
            fill(ctx, poly([CGPoint(x: 45, y: 16), CGPoint(x: 53, y: 4), CGPoint(x: 61, y: 16)]), UIPalette.copper)
            fill(ctx, rounded(CGRect(x: 14, y: 26, width: 34, height: 38), 3), wood)
            for i in 1..<4 { line(ctx, CGPoint(x: 14 + CGFloat(i) * 8.5, y: 28), CGPoint(x: 14 + CGFloat(i) * 8.5, y: 62), wood.adjusted(by: -0.15), 1.2) }
            line(ctx, CGPoint(x: 15, y: 38), CGPoint(x: 47, y: 38), UIColor(hex: 0x5B3E2B), 3)
            line(ctx, CGPoint(x: 15, y: 54), CGPoint(x: 47, y: 54), UIColor(hex: 0x5B3E2B), 3)
            // Banner
            line(ctx, CGPoint(x: 31, y: 26), CGPoint(x: 31, y: 2), ink, 2)
            fill(ctx, poly([CGPoint(x: 31, y: 3), CGPoint(x: 45, y: 7), CGPoint(x: 31, y: 12)]), UIPalette.gold, stroke: 1.2)
        }
    }

    static func shadowTexture() -> SKTexture {
        cachedTexture("shadow", size: CGSize(width: 40, height: 14)) { ctx, size in
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.28).cgColor)
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }

    static func ringTexture(color: UIColor) -> SKTexture {
        cachedTexture("ring-\(color.hashValue)", size: CGSize(width: 46, height: 18)) { ctx, size in
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2))
        }
    }

    static func sparkTexture() -> SKTexture {
        cachedTexture("spark", size: CGSize(width: 16, height: 16)) { ctx, size in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: 8, y: 8), startRadius: 0, endCenter: CGPoint(x: 8, y: 8), endRadius: 8, options: [])
        }
    }

    static func overlayTexture(color: UIColor, size: CGSize) -> SKTexture {
        cachedTexture("overlay-\(color.hashValue)-\(Int(size.width))", size: size) { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
            ctx.addPath(rounded(r, 6))
            ctx.setFillColor(color.withAlphaComponent(0.38).cgColor)
            ctx.fillPath()
            ctx.addPath(rounded(r, 6))
            ctx.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
            ctx.setLineWidth(2.5)
            ctx.strokePath()
        }
    }
}

// MARK: - Outpost buildings

extension Art {
    static let buildingCanvas = CGSize(width: 130, height: 130)

    static func buildingTexture(_ kind: BuildingKind, level: Int, banner: UIColor) -> SKTexture {
        cachedTexture("bld-\(kind.rawValue)-\(level)-\(banner.hashValue)", size: buildingCanvas) { ctx, size in
            drawBuilding(kind, level: level, banner: banner, ctx: ctx, size: size)
        }
    }

    static func buildingImage(_ kind: BuildingKind, level: Int, banner: UIColor = UIPalette.copper) -> UIImage {
        cachedImage("bld-\(kind.rawValue)-\(level)-\(banner.hashValue)", size: buildingCanvas) { ctx, size in
            drawBuilding(kind, level: level, banner: banner, ctx: ctx, size: size)
        }
    }

    private static let wood = UIColor(hex: 0xB07E4A)
    private static let darkWood = UIColor(hex: 0x7A5233)
    private static let roof = UIColor(hex: 0x8B5A3C)
    private static let canvasCloth = UIColor(hex: 0xEADBB8)
    private static let stone = UIColor(hex: 0xA9A196)

    static func flag(_ ctx: CGContext, at p: CGPoint, height: CGFloat, color: UIColor) {
        line(ctx, p, CGPoint(x: p.x, y: p.y - height), ink, 2.2)
        fill(ctx, poly([CGPoint(x: p.x, y: p.y - height), CGPoint(x: p.x + 16, y: p.y - height + 5), CGPoint(x: p.x, y: p.y - height + 11)]), color, stroke: 1.2)
    }

    /// A box drawn in a simple 3/4 view: front face, side face and pitched roof.
    static func house(_ ctx: CGContext, x: CGFloat, baseY: CGFloat, width: CGFloat, height: CGFloat,
                      wall: UIColor, roofColor: UIColor, roofHeight: CGFloat) {
        let depth = width * 0.38
        // Side wall
        fill(ctx, poly([CGPoint(x: x + width, y: baseY), CGPoint(x: x + width + depth, y: baseY - depth * 0.5),
                        CGPoint(x: x + width + depth, y: baseY - depth * 0.5 - height), CGPoint(x: x + width, y: baseY - height)]),
             wall.adjusted(by: -0.12))
        // Front wall
        fill(ctx, CGPath(rect: CGRect(x: x, y: baseY - height, width: width, height: height), transform: nil), wall)
        // Planks
        for i in 1..<4 {
            let yy = baseY - height * CGFloat(i) / 4
            line(ctx, CGPoint(x: x + 2, y: yy), CGPoint(x: x + width - 2, y: yy), wall.adjusted(by: -0.14), 1)
        }
        // Roof
        let top = baseY - height
        fill(ctx, poly([CGPoint(x: x - 5, y: top + 2), CGPoint(x: x + width / 2, y: top - roofHeight),
                        CGPoint(x: x + width / 2 + depth, y: top - roofHeight - depth * 0.5),
                        CGPoint(x: x + width + depth + 5, y: top - depth * 0.5 + 2), CGPoint(x: x + width + 5, y: top + 2)]),
             roofColor)
        fill(ctx, poly([CGPoint(x: x - 5, y: top + 2), CGPoint(x: x + width / 2, y: top - roofHeight), CGPoint(x: x + width + 5, y: top + 2)]),
             wall.adjusted(by: 0.05))
    }

    static func window(_ ctx: CGContext, _ r: CGRect) {
        fill(ctx, rounded(r, 1.5), UIColor(hex: 0xFFD27A), stroke: 1.4)
        line(ctx, CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.midX, y: r.maxY), darkWood, 1)
    }

    static func drawBuilding(_ kind: BuildingKind, level: Int, banner: UIColor, ctx: CGContext, size: CGSize) {
        let groundY: CGFloat = 112
        // Soft ground shadow
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.22).cgColor)
        ctx.fillEllipse(in: CGRect(x: 18, y: groundY - 8, width: 96, height: 22))

        switch kind {
        case .commandCenter:
            if level == 1 {
                // Canvas command tent
                fill(ctx, poly([CGPoint(x: 26, y: groundY), CGPoint(x: 62, y: 46), CGPoint(x: 100, y: groundY)]), canvasCloth)
                fill(ctx, poly([CGPoint(x: 62, y: 46), CGPoint(x: 100, y: groundY), CGPoint(x: 112, y: groundY - 8), CGPoint(x: 76, y: 40)]), canvasCloth.adjusted(by: -0.1))
                fill(ctx, poly([CGPoint(x: 52, y: groundY), CGPoint(x: 62, y: 74), CGPoint(x: 72, y: groundY)]), UIColor(hex: 0x5B3E2B))
                flag(ctx, at: CGPoint(x: 62, y: 48), height: 22, color: banner)
            } else {
                let w: CGFloat = level >= 3 ? 58 : 50
                house(ctx, x: 30, baseY: groundY, width: w, height: level >= 4 ? 44 : 34,
                      wall: level >= 4 ? stone : wood, roofColor: roof, roofHeight: 22)
                fill(ctx, rounded(CGRect(x: 30 + w / 2 - 7, y: groundY - 20, width: 14, height: 20), 3), darkWood)
                window(ctx, CGRect(x: 36, y: groundY - (level >= 4 ? 34 : 28), width: 9, height: 9))
                window(ctx, CGRect(x: 30 + w - 15, y: groundY - (level >= 4 ? 34 : 28), width: 9, height: 9))
                if level >= 3 {
                    fill(ctx, rounded(CGRect(x: 30 + w / 2 - 12, y: groundY - (level >= 4 ? 64 : 54), width: 24, height: 10), 3), banner, stroke: 1.2)
                }
                flag(ctx, at: CGPoint(x: 30 + w / 2 + 10, y: groundY - (level >= 4 ? 64 : 54)), height: 26, color: banner)
                if level >= 4 { flag(ctx, at: CGPoint(x: 26, y: groundY - 30), height: 24, color: UIPalette.gold) }
            }
        case .watchtower:
            let height: CGFloat = [0, 42, 66, 82][min(level, 3)]
            let topY = groundY - height
            // Legs and cross braces
            line(ctx, CGPoint(x: 46, y: groundY), CGPoint(x: 54, y: topY), ink, 5)
            line(ctx, CGPoint(x: 86, y: groundY), CGPoint(x: 78, y: topY), ink, 5)
            line(ctx, CGPoint(x: 46, y: groundY), CGPoint(x: 54, y: topY), wood, 3)
            line(ctx, CGPoint(x: 86, y: groundY), CGPoint(x: 78, y: topY), wood, 3)
            line(ctx, CGPoint(x: 49, y: groundY - 6), CGPoint(x: 80, y: topY + 10), darkWood, 2.2)
            line(ctx, CGPoint(x: 83, y: groundY - 6), CGPoint(x: 52, y: topY + 10), darkWood, 2.2)
            // Platform
            fill(ctx, rounded(CGRect(x: 44, y: topY - 4, width: 44, height: 8), 2), wood)
            fill(ctx, rounded(CGRect(x: 47, y: topY - 16, width: 38, height: 12), 2), wood.adjusted(by: 0.06))
            if level >= 2 {
                // Roof
                line(ctx, CGPoint(x: 49, y: topY - 16), CGPoint(x: 49, y: topY - 30), darkWood, 2.5)
                line(ctx, CGPoint(x: 83, y: topY - 16), CGPoint(x: 83, y: topY - 30), darkWood, 2.5)
                fill(ctx, poly([CGPoint(x: 42, y: topY - 28), CGPoint(x: 66, y: topY - 46), CGPoint(x: 90, y: topY - 28)]), roof)
            }
            if level >= 3 {
                // Beacon fire
                fill(ctx, oval(CGRect(x: 60, y: topY - 26, width: 12, height: 12)), UIColor(hex: 0xFFB347), stroke: 1)
                fill(ctx, oval(CGRect(x: 63, y: topY - 23, width: 6, height: 6)), UIColor(hex: 0xFFF2B0), stroke: 0)
                flag(ctx, at: CGPoint(x: 66, y: topY - 46), height: 18, color: banner)
            } else {
                flag(ctx, at: CGPoint(x: 80, y: topY - 16), height: 18, color: banner)
            }
        case .barracks:
            if level == 1 {
                for i in 0..<3 {
                    fill(ctx, rounded(CGRect(x: 26 + CGFloat(i) * 28, y: groundY - 14 + CGFloat(i % 2) * 4, width: 24, height: 10), 4),
                         [UIPalette.slate, UIPalette.copper, UIPalette.forest][i])
                }
                fill(ctx, poly([CGPoint(x: 40, y: groundY - 18), CGPoint(x: 66, y: 64), CGPoint(x: 92, y: groundY - 18)]), canvasCloth)
            } else {
                house(ctx, x: 22, baseY: groundY, width: level >= 3 ? 64 : 52, height: 30, wall: wood, roofColor: UIColor(hex: 0x6E7F5A), roofHeight: 18)
                fill(ctx, rounded(CGRect(x: 30, y: groundY - 18, width: 12, height: 18), 3), darkWood)
                window(ctx, CGRect(x: 50, y: groundY - 24, width: 9, height: 9))
                if level >= 3 {
                    window(ctx, CGRect(x: 66, y: groundY - 24, width: 9, height: 9))
                    // Weapon rack
                    for i in 0..<3 { line(ctx, CGPoint(x: 100 + CGFloat(i) * 5, y: groundY), CGPoint(x: 102 + CGFloat(i) * 5, y: groundY - 28), UIColor(hex: 0xC5CDD4), 2) }
                }
                flag(ctx, at: CGPoint(x: 24, y: groundY - 30), height: 22, color: banner)
            }
        case .workshop:
            // Anvil and bench always present
            fill(ctx, rounded(CGRect(x: 80, y: groundY - 20, width: 30, height: 6), 2), wood)
            line(ctx, CGPoint(x: 84, y: groundY - 14), CGPoint(x: 84, y: groundY), darkWood, 3)
            line(ctx, CGPoint(x: 106, y: groundY - 14), CGPoint(x: 106, y: groundY), darkWood, 3)
            fill(ctx, poly([CGPoint(x: 86, y: groundY - 20), CGPoint(x: 90, y: groundY - 28), CGPoint(x: 104, y: groundY - 28), CGPoint(x: 108, y: groundY - 24), CGPoint(x: 98, y: groundY - 20)]), UIColor(hex: 0x5E646C), stroke: 1.2)
            if level >= 2 {
                house(ctx, x: 18, baseY: groundY, width: 50, height: 32, wall: wood.adjusted(by: -0.05), roofColor: UIColor(hex: 0x6B6F78), roofHeight: 14)
                fill(ctx, rounded(CGRect(x: 24, y: groundY - 20, width: 18, height: 20), 2), UIColor(hex: 0x3E2A1E))
                fill(ctx, oval(CGRect(x: 28, y: groundY - 12, width: 10, height: 6)), UIColor(hex: 0xFF9A4A), stroke: 0)
            }
            if level >= 3 {
                fill(ctx, rounded(CGRect(x: 56, y: groundY - 66, width: 10, height: 26), 2), stone)
                for i in 0..<3 {
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.5 - CGFloat(i) * 0.12).cgColor)
                    ctx.fillEllipse(in: CGRect(x: 56 + CGFloat(i) * 5, y: groundY - 76 - CGFloat(i) * 9, width: 10 + CGFloat(i) * 3, height: 8 + CGFloat(i) * 2))
                }
                // Gear sign
                fill(ctx, oval(CGRect(x: 66, y: groundY - 46, width: 14, height: 14)), UIPalette.gold, stroke: 1.2)
                fill(ctx, oval(CGRect(x: 70.5, y: groundY - 41.5, width: 5, height: 5)), wood, stroke: 0.8)
            }
        case .supplyDepot:
            // Cart or crates grow into a storehouse
            if level == 1 {
                fill(ctx, rounded(CGRect(x: 38, y: groundY - 30, width: 48, height: 18), 3), wood)
                fill(ctx, oval(CGRect(x: 40, y: groundY - 16, width: 16, height: 16)), darkWood)
                fill(ctx, oval(CGRect(x: 70, y: groundY - 16, width: 16, height: 16)), darkWood)
                fill(ctx, rounded(CGRect(x: 44, y: groundY - 42, width: 14, height: 12), 2), canvasCloth)
                fill(ctx, rounded(CGRect(x: 60, y: groundY - 40, width: 16, height: 10), 2), UIColor(hex: 0xC9974F))
                line(ctx, CGPoint(x: 86, y: groundY - 22), CGPoint(x: 104, y: groundY - 10), darkWood, 3)
            } else {
                house(ctx, x: 30, baseY: groundY, width: 46, height: level >= 3 ? 36 : 26, wall: UIColor(hex: 0xC9974F), roofColor: roof, roofHeight: 12)
                fill(ctx, rounded(CGRect(x: 40, y: groundY - 20, width: 22, height: 20), 2), darkWood)
                line(ctx, CGPoint(x: 40, y: groundY - 20), CGPoint(x: 62, y: groundY), wood, 2)
                line(ctx, CGPoint(x: 62, y: groundY - 20), CGPoint(x: 40, y: groundY), wood, 2)
                let crates = level >= 3 ? 4 : 2
                for i in 0..<crates {
                    let x = 92 + CGFloat(i % 2) * 14
                    let y = groundY - 12 - CGFloat(i / 2) * 12
                    fill(ctx, rounded(CGRect(x: x, y: y, width: 12, height: 12), 1.5), UIColor(hex: 0xD4A160), stroke: 1.2)
                }
                if level >= 3 {
                    fill(ctx, oval(CGRect(x: 18, y: groundY - 18, width: 14, height: 18)), UIColor(hex: 0x9C6B3F))
                    flag(ctx, at: CGPoint(x: 76, y: groundY - 40), height: 18, color: banner)
                }
            }
        }
    }

    static func campfireTexture() -> SKTexture {
        cachedTexture("campfire", size: CGSize(width: 44, height: 26)) { ctx, _ in
            for i in 0..<7 {
                let a = CGFloat(i) / 7 * .pi * 2
                fill(ctx, oval(CGRect(x: 18 + cos(a) * 16, y: 12 + sin(a) * 7, width: 9, height: 7)), UIColor(hex: 0x9A958D), stroke: 1.2)
            }
            line(ctx, CGPoint(x: 12, y: 16), CGPoint(x: 32, y: 10), UIColor(hex: 0x6B4A33), 4)
            line(ctx, CGPoint(x: 12, y: 10), CGPoint(x: 32, y: 16), UIColor(hex: 0x7A5233), 4)
        }
    }

    static func villagerTexture(_ variant: Int) -> SKTexture {
        cachedTexture("villager-\(variant)", size: CGSize(width: 16, height: 24)) { ctx, _ in
            let colors = [UIPalette.slate, UIPalette.copper, UIPalette.forest, UIColor(hex: 0x9A5A7A)]
            fill(ctx, rounded(CGRect(x: 4, y: 10, width: 8, height: 11), 3), colors[variant % colors.count], stroke: 1.1)
            fill(ctx, oval(CGRect(x: 3.5, y: 1, width: 9, height: 9)), skin, stroke: 1.1)
        }
    }
}
