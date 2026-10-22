import SpriteKit
import GameCore

/// Renders the battle as a miniature tabletop diorama and animates rule-engine events.
final class BattleScene: SKScene {
    weak var controller: BattleController?
    var reduceMotion = false
    var fastEnemies = false
    /// Space reserved for SwiftUI HUD overlays (points).
    var boardInsets = UIEdgeInsets(top: 130, left: 10, bottom: 230, right: 10) {
        didSet { if oldValue != boardInsets { relayout() } }
    }

    private var state: BattleState?
    private let world = SKNode()
    private let cameraNode = SKCameraNode()
    private let boardLayer = SKNode()
    private let overlayLayer = SKNode()
    private let pieceLayer = SKNode()
    private let effectsLayer = SKNode()
    private let previewLayer = SKNode()

    private var tileNodes: [GridPoint: SKSpriteNode] = [:]
    private var unitNodes: [Int: UnitNode] = [:]
    private var structureNodes: [GridPoint: SKSpriteNode] = [:]
    private var propNodes: [SKNode] = []

    private(set) var tileW: CGFloat = 50
    private var tileH: CGFloat = 42
    private var depth: CGFloat = 9
    private var origin = CGPoint.zero

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(world)
        world.addChild(boardLayer)
        world.addChild(overlayLayer)
        world.addChild(pieceLayer)
        world.addChild(previewLayer)
        world.addChild(effectsLayer)
        overlayLayer.zPosition = 5
        pieceLayer.zPosition = 10
        previewLayer.zPosition = 900
        effectsLayer.zPosition = 1000
        addChild(cameraNode)
        camera = cameraNode
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Setup and layout

    func setup(with state: BattleState) {
        self.state = state
        backgroundColor = background(for: state.mission.biome)
        relayout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayout()
    }

    private func background(for biome: Biome) -> UIColor {
        switch biome {
        case .forest: return UIColor(hex: 0x2F4A3E)
        case .canyon: return UIColor(hex: 0x6B3F2A)
        case .snow: return UIColor(hex: 0x4A5D70)
        case .ruins: return UIColor(hex: 0x3A2F33)
        }
    }

    private func relayout() {
        guard let state, size.width > 0 else { return }
        let availW = size.width - boardInsets.left - boardInsets.right
        let availH = size.height - boardInsets.top - boardInsets.bottom
        let byWidth = availW / CGFloat(state.width)
        let byHeight = availH / (CGFloat(state.height) * 0.84 + 0.5)
        tileW = floor(min(byWidth, byHeight, 64))
        tileH = floor(tileW * 0.84)
        depth = floor(tileW * 0.18)
        let boardW = tileW * CGFloat(state.width)
        let boardH = tileH * CGFloat(state.height)
        // Centre of the free area, in scene coordinates (anchor is the middle of the screen).
        let centerY = (boardInsets.bottom - boardInsets.top) / 2
        origin = CGPoint(x: -boardW / 2 + tileW / 2, y: centerY + boardH / 2 - tileH / 2)
        rebuildBoard()
        sync(with: state, animated: false)
        Task { @MainActor [weak self] in self?.controller?.refreshOverlays() }
    }

    func position(of p: GridPoint) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(p.x) * tileW, y: origin.y - CGFloat(p.y) * tileH)
    }

    private func z(for p: GridPoint) -> CGFloat { CGFloat(p.y) * 10 + 10 }

    private func rebuildBoard() {
        guard let state else { return }
        boardLayer.removeAllChildren()
        tileNodes.removeAll()
        propNodes.forEach { $0.removeFromParent() }
        propNodes.removeAll()

        let biome = state.mission.biome
        // Diorama slab under the grid
        let boardW = tileW * CGFloat(state.width)
        let boardH = tileH * CGFloat(state.height)
        let slabRect = CGRect(x: -boardW / 2 - 10, y: origin.y + tileH / 2 - boardH - 14, width: boardW + 20, height: boardH + 22)
        let slabSide = SKShapeNode(rect: slabRect.offsetBy(dx: 0, dy: -depth - 6), cornerRadius: 18)
        slabSide.fillColor = Art.sideColor(biome).adjusted(by: -0.12)
        slabSide.strokeColor = .clear
        slabSide.zPosition = -3
        boardLayer.addChild(slabSide)
        let slab = SKShapeNode(rect: slabRect, cornerRadius: 18)
        slab.fillColor = Art.groundColor(.grass, biome: biome).adjusted(by: -0.18)
        slab.strokeColor = UIColor.black.withAlphaComponent(0.25)
        slab.lineWidth = 2
        slab.zPosition = -2
        boardLayer.addChild(slab)

        let tileSize = CGSize(width: tileW, height: tileH)
        for y in 0..<state.height {
            for x in 0..<state.width {
                let p = GridPoint(x, y)
                let terrain = state.terrain(at: p)
                let tex = Art.tileTexture(terrain, biome: biome, variant: (x + y * 3) % 4, size: tileSize, depth: depth)
                let node = SKSpriteNode(texture: tex)
                let raise: CGFloat = terrain == .highGround ? 6 : 0
                node.size = CGSize(width: tileW, height: tileH + depth + raise)
                node.anchorPoint = CGPoint(x: 0.5, y: (depth + raise + tileH / 2) / node.size.height)
                node.position = position(of: p).applying(CGAffineTransform(translationX: 0, y: raise))
                node.zPosition = CGFloat(y) * 0.01
                boardLayer.addChild(node)
                tileNodes[p] = node
                addProps(for: terrain, at: p, biome: biome)
            }
        }
        addScenery(biome: biome, boardW: boardW, boardH: boardH)
    }

    private func addProps(for terrain: Terrain, at p: GridPoint, biome: Biome) {
        let center = position(of: p)
        func place(_ texture: SKTexture, scale: CGFloat, dx: CGFloat, dy: CGFloat) {
            let s = SKSpriteNode(texture: texture)
            s.setScale(scale * tileW / 52)
            s.anchorPoint = CGPoint(x: 0.5, y: 0.08)
            s.position = CGPoint(x: center.x + dx * tileW, y: center.y + dy * tileH)
            s.zPosition = z(for: p) - 1
            pieceLayer.addChild(s)
            propNodes.append(s)
        }
        switch terrain {
        case .forest:
            if biome == .canyon {
                place(Art.cactusTexture(), scale: 0.9, dx: -0.18, dy: 0.05)
                place(Art.cactusTexture(), scale: 0.7, dx: 0.22, dy: -0.15)
            } else {
                place(Art.pineTexture(snowy: biome == .snow), scale: 0.8, dx: -0.22, dy: 0.12)
                place(Art.pineTexture(snowy: biome == .snow), scale: 0.62, dx: 0.24, dy: -0.12)
            }
        case .rock:
            place(Art.boulderTexture(biome: biome), scale: 0.95, dx: 0, dy: -0.25)
        case .ruins:
            place(Art.columnTexture(), scale: 0.7, dx: -0.26, dy: 0.12)
        default:
            break
        }
    }

    private func addScenery(biome: Biome, boardW: CGFloat, boardH: CGFloat) {
        // A row of trees/rocks behind the board and a few in front, for the diorama feel.
        let topY = origin.y + tileH / 2 + 4
        let bottomY = origin.y - boardH + tileH / 2 - 26
        var seed: UInt64 = UInt64(biome.rawValue.count * 31 + 7)
        func rnd() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        let backTex: SKTexture = biome == .canyon ? Art.boulderTexture(biome: biome) :
            (biome == .ruins ? Art.columnTexture() : Art.pineTexture(snowy: biome == .snow))
        var x = -boardW / 2 - 6
        while x < boardW / 2 + 6 {
            let s = SKSpriteNode(texture: backTex)
            s.setScale((0.7 + rnd() * 0.35) * tileW / 52)
            s.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            s.position = CGPoint(x: x, y: topY + rnd() * 8)
            s.zPosition = -1
            s.alpha = 0.95
            boardLayer.addChild(s)
            x += tileW * (0.45 + rnd() * 0.3)
        }
        for i in 0..<4 {
            let s = SKSpriteNode(texture: Art.boulderTexture(biome: biome))
            s.setScale((0.45 + rnd() * 0.2) * tileW / 52)
            s.position = CGPoint(x: -boardW / 2 + boardW * (CGFloat(i) + 0.3 + rnd() * 0.4) / 4, y: bottomY)
            s.zPosition = 950
            boardLayer.addChild(s)
        }
    }

    // MARK: Sync

    /// Brings nodes in line with the state (used after animations and on layout).
    func sync(with state: BattleState, animated: Bool = true) {
        self.state = state
        // Structures
        for (p, node) in structureNodes where state.structures[p] == nil || state.structures[p]?.hp == 0 && state.structures[p]?.kind == .barricade {
            node.removeFromParent()
            structureNodes[p] = nil
        }
        for (p, s) in state.structures {
            let node: SKSpriteNode
            if let existing = structureNodes[p] {
                node = existing
            } else {
                node = SKSpriteNode(texture: s.kind == .gate ? Art.gateTexture() : Art.barricadeTexture())
                node.anchorPoint = CGPoint(x: 0.5, y: 0.12)
                pieceLayer.addChild(node)
                structureNodes[p] = node
                let bar = HealthBar(width: 30)
                bar.name = "hp"
                bar.position = CGPoint(x: 0, y: -6)
                node.addChild(bar)
            }
            node.setScale((s.kind == .gate ? 0.95 : 0.9) * tileW / 52)
            node.position = position(of: p).applying(CGAffineTransform(translationX: 0, y: -tileH * 0.18))
            node.zPosition = z(for: p)
            (node.childNode(withName: "hp") as? HealthBar)?.set(current: s.hp, max: s.maxHP, color: UIPalette.gold)
            node.alpha = s.hp <= 0 ? 0.35 : 1
        }

        // Units
        let alive = Set(state.units.filter(\.isAlive).map(\.id))
        for (id, node) in unitNodes where !alive.contains(id) {
            node.removeFromParent()
            unitNodes[id] = nil
        }
        for unit in state.units where unit.isAlive {
            let node: UnitNode
            if let existing = unitNodes[unit.id] {
                node = existing
            } else {
                node = UnitNode(unit: unit)
                pieceLayer.addChild(node)
                unitNodes[unit.id] = node
                if animated {
                    node.alpha = 0
                    node.position = position(of: unit.position).applying(CGAffineTransform(translationX: 0, y: 40))
                    node.run(.group([.fadeIn(withDuration: 0.3), .move(to: position(of: unit.position), duration: 0.35)]))
                    dust(at: position(of: unit.position))
                }
            }
            node.setScale(tileW / 52)
            if node.action(forKey: "move") == nil && node.alpha > 0 {
                node.position = position(of: unit.position)
            }
            node.zPosition = z(for: unit.position) + 2
            node.update(with: unit, reduceMotion: reduceMotion, isPlayerTurn: state.phase == .player)
        }
    }

    // MARK: Overlays

    func showOverlays(move: [GridPoint], attack: [GridPoint], ability: [GridPoint], threat: [GridPoint],
                      selected: GridPoint?, abilityIsSupport: Bool) {
        overlayLayer.removeAllChildren()
        let size = CGSize(width: tileW, height: tileH)
        func add(_ p: GridPoint, _ color: UIColor, pulse: Bool = false) {
            let node = SKSpriteNode(texture: Art.overlayTexture(color: color, size: CGSize(width: 52, height: 44)))
            node.size = size
            node.position = position(of: p)
            node.zPosition = 1
            overlayLayer.addChild(node)
            if pulse && !reduceMotion {
                node.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
            }
        }
        threat.forEach { add($0, UIColor(hex: 0xE0704F).withAlphaComponent(0.6)) }
        move.forEach { add($0, UIPalette.moveBlue) }
        attack.forEach { add($0, UIPalette.danger, pulse: true) }
        ability.forEach { add($0, abilityIsSupport ? UIPalette.heal : UIPalette.gold, pulse: true) }
        if let s = selected {
            let ring = SKShapeNode(rectOf: CGSize(width: tileW - 4, height: tileH - 4), cornerRadius: 7)
            ring.strokeColor = UIPalette.cream
            ring.lineWidth = 3
            ring.fillColor = UIColor.white.withAlphaComponent(0.12)
            ring.position = position(of: s)
            ring.zPosition = 2
            overlayLayer.addChild(ring)
            if !reduceMotion {
                ring.run(.repeatForever(.sequence([.scale(to: 0.93, duration: 0.45), .scale(to: 1, duration: 0.45)])))
            }
        }
    }

    func showPreview(from: GridPoint, to: GridPoint, damage: Int, lethal: Bool, support: Bool) {
        previewLayer.removeAllChildren()
        let a = position(of: from).applying(CGAffineTransform(translationX: 0, y: tileH * 0.5))
        let b = position(of: to).applying(CGAffineTransform(translationX: 0, y: tileH * 0.5))
        let path = CGMutablePath()
        path.move(to: a)
        path.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + tileH * 0.8))
        let line = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [7, 5]))
        line.strokeColor = support ? UIPalette.heal : UIPalette.cream
        line.lineWidth = 3
        line.glowWidth = 1
        previewLayer.addChild(line)

        let label = SKLabelNode(text: support ? "+" : (lethal ? "−\(damage) KO" : "−\(damage)"))
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 18
        label.fontColor = support ? UIPalette.heal : (lethal ? UIPalette.gold : .white)
        label.verticalAlignmentMode = .center
        let bubbleSize = CGSize(width: max(46, label.frame.width + 18), height: 28)
        let bubble = SKShapeNode(rectOf: bubbleSize, cornerRadius: 14)
        bubble.fillColor = UIPalette.ink.withAlphaComponent(0.92)
        bubble.strokeColor = lethal ? UIPalette.gold : UIPalette.danger
        bubble.lineWidth = 2
        bubble.position = b.applying(CGAffineTransform(translationX: 0, y: tileH * 1.25))
        bubble.addChild(label)
        previewLayer.addChild(bubble)
        if !reduceMotion {
            bubble.setScale(0.6)
            bubble.run(.scale(to: 1, duration: 0.15))
        }
    }

    func clearPreview() {
        previewLayer.removeAllChildren()
    }

    // MARK: Touch

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let state else { return }
        let loc = touch.location(in: world)
        // Prefer tapping a unit's body (they stand taller than their tile).
        let hits = unitNodes.values
            .filter { $0.hitFrame.contains(loc) }
            .sorted { $0.zPosition > $1.zPosition }
        if let node = hits.first, let unit = state.unit(id: node.unitID) {
            // If the player is targeting, a tap on the unit counts as a tap on its tile.
            controller?.handleTap(unit.position)
            return
        }
        var best: (GridPoint, CGFloat)?
        for (p, _) in tileNodes {
            let c = position(of: p)
            let dx = abs(loc.x - c.x) / tileW
            let dy = abs(loc.y - c.y) / tileH
            guard dx <= 0.5 && dy <= 0.5 else { continue }
            let d = dx + dy
            if best == nil || d < best!.1 { best = (p, d) }
        }
        if let p = best?.0 { controller?.handleTap(p) }
    }

    // MARK: Event playback

    func play(_ events: [BattleEvent], state final: BattleState, completion: @escaping () -> Void) {
        var actions: [SKAction] = []
        for event in events {
            actions.append(action(for: event))
        }
        actions.append(.run { [weak self] in self?.sync(with: final) })
        if actions.count == 1 {
            sync(with: final)
            completion()
            return
        }
        run(.sequence(actions + [.run(completion)]))
    }

    private var animSpeed: CGFloat {
        if reduceMotion { return 0.6 }
        if fastEnemies, state?.phase == .enemy { return 0.55 }
        return 1
    }

    private func action(for event: BattleEvent) -> SKAction {
        switch event {
        case .moved(let id, let path):
            guard let node = unitNodes[id], path.count > 1 else { return .wait(forDuration: 0) }
            var steps: [SKAction] = []
            let stepTime = 0.13 * Double(animSpeed)
            for p in path.dropFirst() {
                let target = position(of: p)
                let z = self.z(for: p) + 2
                let hop = SKAction.sequence([.moveBy(x: 0, y: reduceMotion ? 0 : 5, duration: stepTime / 2),
                                             .moveBy(x: 0, y: reduceMotion ? 0 : -5, duration: stepTime / 2)])
                steps.append(.group([.move(to: target, duration: stepTime), .run { node.sprite.run(hop) },
                                     .run { node.zPosition = z }, .run { SoundEngine.shared.play(.step) }]))
            }
            return .run { node.run(.sequence(steps), withKey: "move") }
                .then(.wait(forDuration: stepTime * Double(path.count - 1) + 0.05))

        case .attacked(let attackerID, let target, let damage, let ability):
            guard let attacker = unitNodes[attackerID] else { return .wait(forDuration: 0) }
            let from = attacker.position
            let to = position(of: target)
            let ranged = hypot(to.x - from.x, to.y - from.y) > tileW * 1.3
            var seq: [SKAction] = []
            let t = 0.12 * Double(animSpeed)
            if ranged {
                seq.append(.run { [weak self] in self?.projectile(from: from, to: to, magic: ability == .precisionShot) })
                seq.append(.wait(forDuration: 0.28 * Double(animSpeed)))
            } else {
                let dx = (to.x - from.x) * 0.35, dy = (to.y - from.y) * 0.35
                seq.append(.run { attacker.run(.sequence([.moveBy(x: dx, y: dy, duration: t), .moveBy(x: -dx, y: -dy, duration: t)])) })
                seq.append(.wait(forDuration: t))
            }
            let heavy = damage >= 6 || ability == .smash
            seq.append(.run { [weak self] in
                guard let self else { return }
                SoundEngine.shared.play(heavy ? .heavyHit : .hit)
                Haptics.impact(heavy: heavy)
                self.impact(at: to, damage: damage)
                if let victim = self.unitNodes.values.first(where: { $0.gridPosition == target }) { victim.flash() }
                if let s = self.structureNodes[target] { s.run(.sequence([.moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: -6, y: 0, duration: 0.06), .moveBy(x: 3, y: 0, duration: 0.04)])) }
                if heavy { self.shake() }
            })
            seq.append(.wait(forDuration: 0.3 * Double(animSpeed)))
            return .sequence(seq)

        case .unitDefeated(let id):
            guard let node = unitNodes[id] else { return .wait(forDuration: 0) }
            return .sequence([
                .run { [weak self] in
                    SoundEngine.shared.play(.defeatFoe)
                    self?.poof(at: node.position)
                    node.run(.group([.fadeOut(withDuration: 0.35), .scale(by: 0.6, duration: 0.35), .moveBy(x: 0, y: 10, duration: 0.35)]))
                },
                .wait(forDuration: 0.4 * Double(animSpeed)),
            ])

        case .structureDamaged:
            return .wait(forDuration: 0)

        case .structureDestroyed(let p):
            return .run { [weak self] in
                guard let self, let node = self.structureNodes[p] else { return }
                self.poof(at: node.position)
                SoundEngine.shared.play(.heavyHit)
                if self.state?.structures[p] == nil {
                    node.run(.sequence([.group([.fadeOut(withDuration: 0.3), .scale(by: 0.5, duration: 0.3)]), .removeFromParent()]))
                    self.structureNodes[p] = nil
                }
            }.then(.wait(forDuration: 0.3))

        case .healed(let p, let amount):
            return .run { [weak self] in
                guard let self else { return }
                SoundEngine.shared.play(.heal)
                self.floatText("+\(amount)", at: self.position(of: p), color: UIPalette.heal)
                self.sparkle(at: self.position(of: p), color: UIPalette.heal)
            }.then(.wait(forDuration: 0.45 * Double(animSpeed)))

        case .barricadeBuilt(let p):
            return .run { [weak self] in
                guard let self else { return }
                SoundEngine.shared.play(.build)
                Haptics.impact()
                self.dust(at: self.position(of: p))
            }.then(.wait(forDuration: 0.35))

        case .statusApplied(let id, _):
            return .run { [weak self] in
                guard let self, let node = self.unitNodes[id] else { return }
                SoundEngine.shared.play(.build)
                self.sparkle(at: node.position, color: UIPalette.moveBlue)
                self.floatText("Shield Wall", at: node.position, color: UIPalette.moveBlue)
            }.then(.wait(forDuration: 0.45))

        case .dashed(let id):
            return .run { [weak self] in
                guard let self, let node = self.unitNodes[id] else { return }
                SoundEngine.shared.play(.select)
                self.floatText("Dash +3", at: node.position, color: UIPalette.gold)
            }.then(.wait(forDuration: 0.35))

        case .reinforcementsArrived:
            return .run { SoundEngine.shared.play(.turn) }.then(.wait(forDuration: 0.1))

        case .phaseChanged:
            return .wait(forDuration: 0)
        }
    }

    // MARK: Effects

    private func projectile(from: CGPoint, to: CGPoint, magic: Bool) {
        let arrow = SKShapeNode(rectOf: CGSize(width: 16, height: 3), cornerRadius: 1.5)
        arrow.fillColor = magic ? UIPalette.gold : UIColor(hex: 0xEDE3CF)
        arrow.strokeColor = UIPalette.ink
        arrow.lineWidth = 1
        let start = from.applying(CGAffineTransform(translationX: 0, y: 26))
        let end = to.applying(CGAffineTransform(translationX: 0, y: 18))
        arrow.position = start
        arrow.zRotation = atan2(end.y - start.y, end.x - start.x)
        effectsLayer.addChild(arrow)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) + 40))
        arrow.run(.sequence([.follow(path, asOffset: false, orientToPath: true, duration: 0.26 * Double(animSpeed)), .removeFromParent()]))
        if magic { sparkle(at: start, color: UIPalette.gold) }
    }

    private func impact(at p: CGPoint, damage: Int) {
        floatText("−\(damage)", at: p, color: .white, big: damage >= 6)
        let burst = SKEmitterNode()
        burst.particleTexture = Art.sparkTexture()
        burst.particleBirthRate = 600
        burst.numParticlesToEmit = reduceMotion ? 6 : 16
        burst.particleLifetime = 0.35
        burst.particleSpeed = 110
        burst.particleSpeedRange = 60
        burst.emissionAngleRange = .pi * 2
        burst.particleScale = 0.6
        burst.particleScaleSpeed = -1.4
        burst.particleColor = UIPalette.gold
        burst.particleColorBlendFactor = 1
        burst.particleAlphaSpeed = -2.5
        burst.position = p.applying(CGAffineTransform(translationX: 0, y: 22))
        effectsLayer.addChild(burst)
        burst.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
    }

    private func floatText(_ text: String, at p: CGPoint, color: UIColor, big: Bool = false) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = big ? 26 : 20
        label.fontColor = color
        label.position = p.applying(CGAffineTransform(translationX: 0, y: 46))
        let shadow = SKLabelNode(text: text)
        shadow.fontName = label.fontName
        shadow.fontSize = label.fontSize
        shadow.fontColor = UIPalette.ink
        shadow.position = CGPoint(x: 1.5, y: -2)
        shadow.zPosition = -1
        label.addChild(shadow)
        effectsLayer.addChild(label)
        label.setScale(0.5)
        label.run(.sequence([
            .group([.scale(to: 1, duration: 0.12), .moveBy(x: 0, y: 26, duration: 0.7)]),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
    }

    private func poof(at p: CGPoint) {
        for i in 0..<(reduceMotion ? 3 : 7) {
            let puff = SKShapeNode(circleOfRadius: CGFloat(5 + i % 3 * 2))
            puff.fillColor = UIColor(white: 0.95, alpha: 0.9)
            puff.strokeColor = .clear
            puff.position = p.applying(CGAffineTransform(translationX: 0, y: 18))
            effectsLayer.addChild(puff)
            let a = CGFloat(i) / 7 * .pi * 2
            puff.run(.sequence([
                .group([.moveBy(x: cos(a) * 26, y: sin(a) * 16 + 10, duration: 0.45), .fadeOut(withDuration: 0.45), .scale(to: 1.8, duration: 0.45)]),
                .removeFromParent(),
            ]))
        }
    }

    private func dust(at p: CGPoint) {
        for i in 0..<5 {
            let puff = SKShapeNode(circleOfRadius: 4)
            puff.fillColor = UIColor(hex: 0xE8D7AE, alpha: 0.85)
            puff.strokeColor = .clear
            puff.position = p
            effectsLayer.addChild(puff)
            let dir: CGFloat = i % 2 == 0 ? 1 : -1
            puff.run(.sequence([
                .group([.moveBy(x: dir * CGFloat(10 + i * 4), y: 6, duration: 0.4), .fadeOut(withDuration: 0.4), .scale(to: 2, duration: 0.4)]),
                .removeFromParent(),
            ]))
        }
    }

    private func sparkle(at p: CGPoint, color: UIColor) {
        let e = SKEmitterNode()
        e.particleTexture = Art.sparkTexture()
        e.particleBirthRate = 60
        e.numParticlesToEmit = reduceMotion ? 5 : 14
        e.particleLifetime = 0.8
        e.particleSpeed = 30
        e.particleSpeedRange = 20
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi
        e.particlePositionRange = CGVector(dx: 30, dy: 10)
        e.particleScale = 0.5
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleAlphaSpeed = -1.2
        e.position = p.applying(CGAffineTransform(translationX: 0, y: 10))
        effectsLayer.addChild(e)
        e.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func shake() {
        guard !reduceMotion else { return }
        cameraNode.run(.sequence([
            .moveBy(x: 4, y: -2, duration: 0.04), .moveBy(x: -7, y: 3, duration: 0.05),
            .moveBy(x: 5, y: -2, duration: 0.05), .move(to: .zero, duration: 0.04),
        ]))
    }

    func celebrate() {
        guard let state else { return }
        for unit in state.units(of: .player) {
            guard let node = unitNodes[unit.id] else { continue }
            if !reduceMotion {
                node.sprite.run(.repeat(.sequence([.moveBy(x: 0, y: 10, duration: 0.15), .moveBy(x: 0, y: -10, duration: 0.15)]), count: 3))
            }
            sparkle(at: node.position, color: UIPalette.gold)
        }
    }
}

private extension SKAction {
    func then(_ next: SKAction) -> SKAction { .sequence([self, next]) }
}

// MARK: - Unit node

final class UnitNode: SKNode {
    let unitID: Int
    let kind: UnitClass
    let sprite: SKSpriteNode
    private let shadow: SKSpriteNode
    private let ring: SKSpriteNode
    private let hpBar: HealthBar
    private let shieldIcon: SKLabelNode
    private(set) var gridPosition: GridPoint
    private var idleStarted = false

    init(unit: BattleUnit) {
        unitID = unit.id
        kind = unit.kind
        gridPosition = unit.position
        sprite = SKSpriteNode(texture: Art.unitTexture(unit.kind))
        sprite.size = CGSize(width: 54, height: 66)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        shadow = SKSpriteNode(texture: Art.shadowTexture())
        shadow.size = CGSize(width: 38, height: 13)
        ring = SKSpriteNode(texture: Art.ringTexture(color: unit.faction == .player ? UIPalette.moveBlue : UIPalette.danger))
        ring.size = CGSize(width: 44, height: 17)
        hpBar = HealthBar(width: 34)
        shieldIcon = SKLabelNode(text: "🛡")
        super.init()
        addChild(shadow)
        addChild(ring)
        addChild(sprite)
        addChild(hpBar)
        shadow.position = CGPoint(x: 0, y: -2)
        ring.position = CGPoint(x: 0, y: -2)
        hpBar.position = CGPoint(x: 0, y: unit.kind == .brute || unit.kind == .warlord ? 76 : 68)
        shieldIcon.fontSize = 14
        shieldIcon.position = CGPoint(x: 20, y: 40)
        shieldIcon.isHidden = true
        addChild(shieldIcon)
        if unit.faction == .enemy { sprite.xScale = -1 }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var hitFrame: CGRect {
        let s = xScale
        return CGRect(x: position.x - 22 * s, y: position.y - 6 * s, width: 44 * s, height: 70 * s)
    }

    func update(with unit: BattleUnit, reduceMotion: Bool, isPlayerTurn: Bool) {
        gridPosition = unit.position
        hpBar.set(current: unit.hp, max: unit.stats.maxHP, color: unit.faction == .player ? UIPalette.heal : UIPalette.danger)
        shieldIcon.isHidden = !unit.has(.shielded)
        let exhausted = unit.faction == .player && isPlayerTurn && unit.isExhausted
        sprite.color = .gray
        sprite.colorBlendFactor = exhausted ? 0.45 : 0
        ring.alpha = exhausted ? 0.35 : 1
        if !idleStarted && !reduceMotion {
            idleStarted = true
            let delay = Double(unitID % 5) * 0.13
            sprite.run(.sequence([.wait(forDuration: delay), .repeatForever(.sequence([
                .scaleY(to: 1.03, duration: 0.6), .scaleY(to: 1.0, duration: 0.6),
            ]))]))
        }
    }

    func flash() {
        sprite.run(.sequence([
            .colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05),
            .wait(forDuration: 0.12),
            .colorize(withColorBlendFactor: 0, duration: 0.15),
        ]))
        run(.sequence([.moveBy(x: 4, y: 0, duration: 0.04), .moveBy(x: -8, y: 0, duration: 0.06), .moveBy(x: 4, y: 0, duration: 0.04)]))
    }
}

final class HealthBar: SKNode {
    private let back: SKShapeNode
    private let front: SKShapeNode
    private let width: CGFloat

    init(width: CGFloat) {
        self.width = width
        back = SKShapeNode(rectOf: CGSize(width: width + 4, height: 8), cornerRadius: 4)
        back.fillColor = UIPalette.ink.withAlphaComponent(0.85)
        back.strokeColor = UIColor.white.withAlphaComponent(0.5)
        back.lineWidth = 1
        front = SKShapeNode()
        super.init()
        addChild(back)
        addChild(front)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func set(current: Int, max: Int, color: UIColor) {
        let frac = max > 0 ? CGFloat(Swift.max(0, current)) / CGFloat(max) : 0
        let w = Swift.max(0.5, width * frac)
        let r = Swift.min(2.5, w / 2)
        front.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -2.5, width: w, height: 5), cornerWidth: r, cornerHeight: r, transform: nil)
        front.fillColor = frac < 0.35 ? UIPalette.gold : color
        front.strokeColor = .clear
    }
}
