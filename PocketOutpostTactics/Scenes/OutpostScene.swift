import SpriteKit
import GameCore

/// The home base: a floating diorama island at dusk whose buildings change with each upgrade.
final class OutpostScene: SKScene {
    var onSelect: ((BuildingKind) -> Void)?
    var reduceMotion = false
    var topInset: CGFloat = 120
    var bottomInset: CGFloat = 220

    private let island = SKNode()
    private var buildingNodes: [BuildingKind: SKSpriteNode] = [:]
    private var levels: [BuildingKind: Int] = [:]
    private var bannerColor = UIPalette.copper
    private var highlight: SKNode?
    private var scaleFactor: CGFloat = 1

    /// Relative placements on the island (x right, y up), ordered back to front.
    static let layout: [(BuildingKind, CGPoint)] = [
        (.commandCenter, CGPoint(x: 0.0, y: 0.30)),
        (.watchtower, CGPoint(x: -0.33, y: 0.10)),
        (.barracks, CGPoint(x: 0.33, y: 0.10)),
        (.workshop, CGPoint(x: -0.25, y: -0.24)),
        (.supplyDepot, CGPoint(x: 0.27, y: -0.24)),
    ]

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x1F2B36)
        addChild(island)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(profile: PlayerProfile, banner: UIColor, highlight: BuildingKind?) {
        var newLevels: [BuildingKind: Int] = [:]
        for kind in BuildingKind.allCases { newLevels[kind] = profile.level(of: kind) }
        let changed = newLevels != levels || banner != bannerColor
        levels = newLevels
        bannerColor = banner
        if changed || island.children.isEmpty { rebuild() }
        setHighlight(highlight)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuild()
    }

    private var islandSize: CGSize {
        let w = min(size.width - 16, 460)
        let availH = size.height - topInset - bottomInset
        return CGSize(width: w, height: min(w * 0.78, availH))
    }

    private func rebuild() {
        guard size.width > 0, !levels.isEmpty else { return }
        island.removeAllChildren()
        buildingNodes.removeAll()
        let isz = islandSize
        scaleFactor = isz.width / 390
        island.position = CGPoint(x: 0, y: (bottomInset - topInset) / 2)

        addSky()
        addIsland(isz)
        addTrees(isz)

        for (kind, rel) in Self.layout {
            let level = levels[kind] ?? 1
            let node = SKSpriteNode(texture: Art.buildingTexture(kind, level: level, banner: bannerColor))
            node.size = CGSize(width: 130 * scaleFactor * 0.92, height: 130 * scaleFactor * 0.92)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.14)
            node.position = CGPoint(x: rel.x * isz.width, y: rel.y * isz.height)
            node.zPosition = 100 - rel.y * 100
            node.name = kind.rawValue
            island.addChild(node)
            buildingNodes[kind] = node
            addSign(for: kind, level: level, on: node)
        }
        addCampfire(at: CGPoint(x: 0, y: -0.02 * isz.height))
        addVillagers(isz)
        if let h = highlightKind { setHighlight(h, force: true) }
    }

    private func addSky() {
        guard !reduceMotion else { return }
        for i in 0..<18 {
            let star = SKShapeNode(circleOfRadius: CGFloat(i % 3) * 0.5 + 0.8)
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = 0.5
            let x = CGFloat((i * 73) % 100) / 100 * size.width - size.width / 2
            let y = size.height / 2 - CGFloat((i * 37) % 100) / 100 * size.height * 0.35
            star.position = CGPoint(x: x, y: y - island.position.y)
            star.zPosition = -50
            island.addChild(star)
            star.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 1 + Double(i % 4) * 0.4), .fadeAlpha(to: 0.7, duration: 1.2)])))
        }
    }

    private func addIsland(_ isz: CGSize) {
        let w = isz.width / 2, h = isz.height / 2
        func diamond(_ dy: CGFloat, _ scale: CGFloat) -> CGPath {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: h * scale + dy))
            p.addQuadCurve(to: CGPoint(x: w * scale, y: dy), control: CGPoint(x: w * scale * 0.75, y: h * scale * 0.75 + dy))
            p.addQuadCurve(to: CGPoint(x: 0, y: -h * scale + dy), control: CGPoint(x: w * scale * 0.75, y: -h * scale * 0.75 + dy))
            p.addQuadCurve(to: CGPoint(x: -w * scale, y: dy), control: CGPoint(x: -w * scale * 0.75, y: -h * scale * 0.75 + dy))
            p.addQuadCurve(to: CGPoint(x: 0, y: h * scale + dy), control: CGPoint(x: -w * scale * 0.75, y: h * scale * 0.75 + dy))
            p.closeSubpath()
            return p
        }
        let earth = SKShapeNode(path: diamond(-26 * scaleFactor, 1))
        earth.fillColor = UIColor(hex: 0x6B4B33)
        earth.strokeColor = UIColor(hex: 0x3E2A1E)
        earth.lineWidth = 2
        earth.zPosition = -10
        island.addChild(earth)
        let earth2 = SKShapeNode(path: diamond(-46 * scaleFactor, 0.82))
        earth2.fillColor = UIColor(hex: 0x4E3624)
        earth2.strokeColor = .clear
        earth2.zPosition = -11
        island.addChild(earth2)
        let grass = SKShapeNode(path: diamond(0, 1))
        grass.fillColor = UIColor(hex: 0x6E9A5E)
        grass.strokeColor = UIColor(hex: 0x3F5F3E)
        grass.lineWidth = 2.5
        grass.zPosition = -9
        island.addChild(grass)
        let lit = SKShapeNode(path: diamond(4 * scaleFactor, 0.62))
        lit.fillColor = UIColor(hex: 0x86B26F).withAlphaComponent(0.6)
        lit.strokeColor = .clear
        lit.zPosition = -8
        island.addChild(lit)
        // Dirt trails toward the fire
        for (kind, rel) in Self.layout {
            _ = kind
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rel.x * isz.width, y: rel.y * isz.height - 8))
            path.addLine(to: CGPoint(x: 0, y: -0.02 * isz.height))
            let trail = SKShapeNode(path: path)
            trail.strokeColor = UIColor(hex: 0xC9A97A).withAlphaComponent(0.75)
            trail.lineWidth = 10 * scaleFactor
            trail.lineCap = .round
            trail.zPosition = -7
            island.addChild(trail)
        }
    }

    private func addTrees(_ isz: CGSize) {
        let spots: [CGPoint] = [
            CGPoint(x: -0.12, y: 0.42), CGPoint(x: 0.14, y: 0.43), CGPoint(x: -0.42, y: 0.18), CGPoint(x: 0.44, y: 0.2),
            CGPoint(x: -0.47, y: -0.02), CGPoint(x: 0.48, y: -0.02), CGPoint(x: -0.05, y: -0.42), CGPoint(x: 0.36, y: -0.36),
        ]
        for (i, s) in spots.enumerated() {
            let tree = SKSpriteNode(texture: Art.pineTexture(snowy: false))
            tree.setScale(scaleFactor * (i % 2 == 0 ? 1.1 : 0.85))
            tree.anchorPoint = CGPoint(x: 0.5, y: 0.08)
            tree.position = CGPoint(x: s.x * isz.width, y: s.y * isz.height)
            tree.zPosition = 100 - s.y * 100
            island.addChild(tree)
            if !reduceMotion {
                tree.run(.repeatForever(.sequence([.rotate(toAngle: 0.025, duration: 1.6 + Double(i) * 0.1), .rotate(toAngle: -0.025, duration: 1.6)])))
            }
        }
    }

    private func addSign(for kind: BuildingKind, level: Int, on node: SKSpriteNode) {
        let label = SKLabelNode(text: "Lv \(level)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 11
        label.fontColor = UIPalette.cream
        label.verticalAlignmentMode = .center
        let pill = SKShapeNode(rectOf: CGSize(width: 38, height: 18), cornerRadius: 9)
        pill.fillColor = UIPalette.ink.withAlphaComponent(0.85)
        pill.strokeColor = level >= kind.maxLevel ? UIPalette.gold : UIPalette.cream.withAlphaComponent(0.3)
        pill.lineWidth = 1.5
        pill.addChild(label)
        pill.position = CGPoint(x: 0, y: -10)
        pill.zPosition = 5
        node.addChild(pill)
    }

    private func addCampfire(at p: CGPoint) {
        let fire = SKSpriteNode(texture: Art.campfireTexture())
        fire.setScale(scaleFactor * 1.1)
        fire.position = p
        fire.zPosition = 100 - p.y / max(islandSize.height, 1) * 100
        island.addChild(fire)

        let glow = SKShapeNode(circleOfRadius: 46 * scaleFactor)
        glow.fillColor = UIColor(hex: 0xFFB347).withAlphaComponent(0.16)
        glow.strokeColor = .clear
        glow.position = p
        glow.zPosition = -6
        glow.blendMode = .add
        island.addChild(glow)

        let flames = SKEmitterNode()
        flames.particleTexture = Art.sparkTexture()
        flames.particleBirthRate = reduceMotion ? 18 : 45
        flames.particleLifetime = 0.9
        flames.particleLifetimeRange = 0.3
        flames.particlePositionRange = CGVector(dx: 14 * scaleFactor, dy: 2)
        flames.particleSpeed = 34 * scaleFactor
        flames.particleSpeedRange = 12
        flames.emissionAngle = .pi / 2
        flames.emissionAngleRange = 0.35
        flames.particleScale = 1.1 * scaleFactor
        flames.particleScaleSpeed = -1.0
        flames.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [UIColor(hex: 0xFFF2B0), UIColor(hex: 0xFFB347), UIColor(hex: 0xE0533A), UIColor(hex: 0x553333).withAlphaComponent(0)],
            times: [0, 0.3, 0.7, 1])
        flames.particleColorBlendFactor = 1
        flames.particleBlendMode = .add
        flames.position = CGPoint(x: p.x, y: p.y + 8 * scaleFactor)
        flames.zPosition = fire.zPosition + 1
        island.addChild(flames)

        if !reduceMotion {
            glow.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.5), .scale(to: 0.95, duration: 0.6)])))
            let fireflies = SKEmitterNode()
            fireflies.particleTexture = Art.sparkTexture()
            fireflies.particleBirthRate = 1.5
            fireflies.particleLifetime = 5
            fireflies.particlePositionRange = CGVector(dx: islandSize.width * 0.8, dy: islandSize.height * 0.6)
            fireflies.particleSpeed = 8
            fireflies.emissionAngleRange = .pi * 2
            fireflies.particleScale = 0.35
            fireflies.particleColor = UIColor(hex: 0xEFFF9A)
            fireflies.particleColorBlendFactor = 1
            fireflies.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.9, 0], times: [0, 0.5, 1])
            fireflies.zPosition = 400
            fireflies.advanceSimulationTime(5)
            island.addChild(fireflies)
        }
    }

    private func addVillagers(_ isz: CGSize) {
        let count = 2 + (levels.values.reduce(0, +) - levels.count) / 2
        for i in 0..<min(count, 7) {
            let v = SKSpriteNode(texture: Art.villagerTexture(i))
            v.setScale(scaleFactor * 1.1)
            v.anchorPoint = CGPoint(x: 0.5, y: 0.05)
            let (kind, rel) = Self.layout[i % Self.layout.count]
            _ = kind
            let home = CGPoint(x: rel.x * isz.width * 0.8, y: rel.y * isz.height * 0.8 - 14)
            let fire = CGPoint(x: (i % 2 == 0 ? -1 : 1) * 26 * scaleFactor, y: -0.02 * isz.height - 10)
            v.position = home
            v.zPosition = 100 - home.y / isz.height * 100
            island.addChild(v)
            guard !reduceMotion else { continue }
            let walkTime = 3.5 + Double(i) * 0.4
            v.run(.repeatForever(.sequence([
                .wait(forDuration: Double(i) * 0.7),
                .move(to: fire, duration: walkTime),
                .wait(forDuration: 2),
                .move(to: home, duration: walkTime),
                .wait(forDuration: 1.5),
            ])))
            v.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.18), .moveBy(x: 0, y: -2, duration: 0.18)])))
        }
    }

    // MARK: Highlight

    private var highlightKind: BuildingKind?

    private func setHighlight(_ kind: BuildingKind?, force: Bool = false) {
        guard force || kind != highlightKind else { return }
        highlight?.removeFromParent()
        highlight = nil
        highlightKind = kind
        guard let kind, let node = buildingNodes[kind] else { return }
        let arrow = SKLabelNode(text: "▼")
        arrow.fontSize = 28
        arrow.fontColor = UIPalette.gold
        arrow.position = CGPoint(x: node.position.x, y: node.position.y + node.size.height * 0.9)
        arrow.zPosition = 500
        island.addChild(arrow)
        arrow.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.4), .moveBy(x: 0, y: -8, duration: 0.4)])))
        highlight = arrow
    }

    // MARK: Upgrade animation

    func playUpgrade(_ kind: BuildingKind, newLevel: Int) {
        guard let node = buildingNodes[kind] else { return }
        levels[kind] = newLevel
        let newTexture = Art.buildingTexture(kind, level: newLevel, banner: bannerColor)
        // Scaffolding shake, dust, then the new building pops in with sparkles.
        let dust = SKEmitterNode()
        dust.particleTexture = Art.sparkTexture()
        dust.particleBirthRate = 120
        dust.numParticlesToEmit = 40
        dust.particleLifetime = 0.9
        dust.particlePositionRange = CGVector(dx: node.size.width * 0.7, dy: 10)
        dust.particleSpeed = 50
        dust.emissionAngle = .pi / 2
        dust.emissionAngleRange = 1.2
        dust.particleScale = 1.4
        dust.particleScaleSpeed = 0.6
        dust.particleColor = UIColor(hex: 0xE8D7AE)
        dust.particleColorBlendFactor = 1
        dust.particleAlphaSpeed = -1.1
        dust.position = CGPoint(x: node.position.x, y: node.position.y + 6)
        dust.zPosition = node.zPosition + 1
        island.addChild(dust)
        dust.run(.sequence([.wait(forDuration: 2), .removeFromParent()]))

        let shake = SKAction.sequence((0..<6).map { i in .moveBy(x: i % 2 == 0 ? 3 : -3, y: 0, duration: 0.05) })
        node.run(.sequence([
            reduceMotion ? .wait(forDuration: 0.1) : shake,
            .scaleY(to: 0.85, duration: 0.12),
            .run { node.texture = newTexture },
            .scaleY(to: 1.08, duration: 0.14),
            .scaleY(to: 1.0, duration: 0.1),
            .run { [weak self] in self?.rebuild() },
        ]))
        let sparkle = SKEmitterNode()
        sparkle.particleTexture = Art.sparkTexture()
        sparkle.particleBirthRate = 80
        sparkle.numParticlesToEmit = 30
        sparkle.particleLifetime = 1.2
        sparkle.particlePositionRange = CGVector(dx: node.size.width * 0.8, dy: node.size.height * 0.6)
        sparkle.particleSpeed = 20
        sparkle.emissionAngle = .pi / 2
        sparkle.particleScale = 0.6
        sparkle.particleColor = UIPalette.gold
        sparkle.particleColorBlendFactor = 1
        sparkle.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0], times: [0, 0.3, 1])
        sparkle.position = CGPoint(x: node.position.x, y: node.position.y + node.size.height * 0.4)
        sparkle.zPosition = 450
        island.addChild(sparkle)
        sparkle.run(.sequence([.wait(forDuration: 2.5), .removeFromParent()]))
    }

    // MARK: Touch

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: island)
        let hit = buildingNodes
            .filter { _, node in
                let f = node.frame.insetBy(dx: node.size.width * 0.12, dy: node.size.height * 0.08)
                return f.contains(loc)
            }
            .max { $0.value.zPosition < $1.value.zPosition }
        if let kind = hit?.key {
            buildingNodes[kind]?.run(.sequence([.scale(to: 1.06, duration: 0.08), .scale(to: 1, duration: 0.1)]))
            onSelect?(kind)
        }
    }
}
