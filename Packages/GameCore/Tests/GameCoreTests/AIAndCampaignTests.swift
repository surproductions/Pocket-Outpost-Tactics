import XCTest
@testable import GameCore

final class EnemyAITests: XCTestCase {
    func testRaiderPrefersKillingWoundedTarget() {
        var battle = makeBattle([
            ".......",
            ".1.r.2.",
            ".......",
        ], squad: [.guardian, .ranger])
        let ranger = battle.firstUnit(.ranger)
        battle.setHP(ranger.id, 3)
        battle.endPlayerTurn()
        let raider = battle.firstUnit(.raider)
        let decision = TacticalAI.decide(for: raider.id, in: battle)
        XCTAssertEqual(decision.action, .attack(ranger.position))
    }

    func testArcherKeepsDistance() {
        var battle = makeBattle([
            ".......",
            ".......",
            "...a...",
            "...1...",
            ".......",
            ".......",
        ], squad: [.guardian])
        battle.endPlayerTurn()
        let archer = battle.firstUnit(.archer)
        let decision = TacticalAI.decide(for: archer.id, in: battle)
        guard case .attack(let target) = decision.action, let dest = decision.moveTo else {
            return XCTFail("Archer should step back and shoot, got \(decision)")
        }
        XCTAssertEqual(target, GridPoint(3, 3))
        XCTAssertGreaterThanOrEqual(dest.distance(to: target), 2)
    }

    func testRaiderAdvancesWhenNothingInReach() {
        var battle = makeBattle([
            "r......",
            ".......",
            ".......",
            ".......",
            ".......",
            ".......",
            ".......",
            "......1",
        ], squad: [.guardian])
        battle.endPlayerTurn()
        let raider = battle.firstUnit(.raider)
        let before = raider.position.distance(to: GridPoint(6, 7))
        let decision = TacticalAI.decide(for: raider.id, in: battle)
        XCTAssertNotNil(decision.moveTo)
        XCTAssertLessThan(decision.moveTo!.distance(to: GridPoint(6, 7)), before)
    }

    func testRaidersTargetGateInDefendMissions() {
        var battle = makeBattle([
            ".......",
            "...r...",
            ".......",
            "...G...",
            "1......",
        ], squad: [.guardian], objective: .defend(rounds: 5))
        battle.endPlayerTurn()
        let raider = battle.firstUnit(.raider)
        let decision = TacticalAI.decide(for: raider.id, in: battle)
        XCTAssertEqual(decision.action, .attack(GridPoint(3, 3)))
    }

    func testDecisionsAreDeterministic() {
        let mission = Campaign.chapters[0].missions[6]
        var a = BattleState(mission: mission, squad: [.guardian, .ranger, .scout, .engineer].map { SquadMember(kind: $0, level: 3) })
        var b = a
        TacticalAI.simulate(&a)
        TacticalAI.simulate(&b)
        XCTAssertEqual(a.phase, b.phase)
        XCTAssertEqual(a.round, b.round)
        XCTAssertEqual(a.units.map(\.hp), b.units.map(\.hp))
    }
}

final class CampaignTests: XCTestCase {
    func testCampaignShape() {
        XCTAssertEqual(Campaign.chapters.count, 4)
        XCTAssertEqual(Campaign.chapters[0].missions.count, 10)
        let objectives = Set(Campaign.chapters[0].missions.map { m -> String in
            if case .defend = m.objective { return "defend" } else { return "eliminate" }
        })
        XCTAssertEqual(objectives, ["defend", "eliminate"])
        XCTAssertEqual(Set(Campaign.allMissions.map(\.id)).count, Campaign.allMissions.count, "Unique ids")
    }

    func testEveryMapIsWellFormed() {
        for mission in Campaign.allMissions {
            XCTAssertEqual(mission.height, 9, mission.id)
            XCTAssertTrue(mission.rows.allSatisfy { $0.count == 7 }, mission.id)
            let layout = mission.parse()
            XCTAssertGreaterThanOrEqual(layout.deploySlots.count, 1, mission.id)
            XCTAssertFalse(layout.enemies.isEmpty, mission.id)
            XCTAssertTrue(MapGenerator.isConnected(mission.rows), "\(mission.id) has unreachable tiles")
            if case .defend = mission.objective {
                XCTAssertNotNil(layout.structures.values.first { $0.kind == .gate }, mission.id)
            }
        }
    }

    func testGeneratorIsDeterministic() {
        let a = MapGenerator.dailyChallenge(dayNumber: 20_000, highestChapter: 3)
        let b = MapGenerator.dailyChallenge(dayNumber: 20_000, highestChapter: 3)
        let c = MapGenerator.dailyChallenge(dayNumber: 20_001, highestChapter: 3)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a.rows, c.rows)
        XCTAssertTrue(MapGenerator.isConnected(a.rows))
    }

    /// Squad levels a player would roughly have when reaching each chapter-1 mission.
    static let expectedLevels: [[UnitClass: Int]] = [
        [.guardian: 1],
        [.guardian: 1, .ranger: 1],
        [.guardian: 2, .ranger: 1],
        [.guardian: 2, .ranger: 2, .scout: 1],
        [.guardian: 3, .ranger: 2, .scout: 1],
        [.guardian: 3, .ranger: 3, .scout: 2, .engineer: 1],
        [.guardian: 3, .ranger: 3, .scout: 3, .engineer: 2],
        [.guardian: 4, .ranger: 4, .scout: 3, .engineer: 2],
        [.guardian: 4, .ranger: 4, .scout: 3, .engineer: 3],
        [.guardian: 4, .ranger: 4, .scout: 4, .engineer: 3],
    ]

    /// Deterministic playthrough: the AI plays the player's side of every chapter-1 mission and must
    /// win. If a simple greedy AI can win, a thoughtful player can too.
    func testChapterOneIsWinnableByAutoPlay() {
        var report: [String] = []
        var failures: [String] = []
        for (i, mission) in Campaign.chapters[0].missions.enumerated() {
            let levels = Self.expectedLevels[i]
            let classes = (mission.allowedClasses ?? UnitClass.playerClasses).filter { levels[$0] != nil }
            let squad = classes.map { SquadMember(kind: $0, level: levels[$0]!) }
            let modifiers = SquadModifiers(rangedAttackBonus: i >= 1 ? 1 : 0, bonusMaxHP: i >= 4 ? 2 : 0,
                                           engineerBonus: i >= 6 ? 1 : 0)
            var battle = BattleState(mission: mission, squad: squad, modifiers: modifiers)
            TacticalAI.simulate(&battle)
            report.append("\(mission.id) \(battle.phase) round \(battle.round) stars \(battle.stars) lost \(battle.playerUnitsLost)")
            if battle.phase != .victory { failures.append(mission.id) }
        }
        print("AUTOPLAY REPORT\n" + report.joined(separator: "\n"))
        XCTAssertTrue(failures.isEmpty, "Not winnable by auto-play: \(failures)")
    }

    func testLaterChaptersReport() {
        var lines: [String] = []
        for chapter in Campaign.chapters.dropFirst() {
            let level = min(5, 3 + chapter.id / 2)
            for mission in chapter.missions {
                let squad = UnitClass.playerClasses.map { SquadMember(kind: $0, level: level) }
                var battle = BattleState(mission: mission, squad: squad,
                                         modifiers: SquadModifiers(rangedAttackBonus: 2, bonusMaxHP: 4, engineerBonus: 2))
                TacticalAI.simulate(&battle)
                lines.append("\(mission.id) \(mission.title) \(battle.phase) round \(battle.round)")
            }
        }
        print("LATER CHAPTERS REPORT\n" + lines.joined(separator: "\n"))
    }
}

final class EconomyTests: XCTestCase {
    func testFirstClearRewardsAndUnlock() {
        var profile = PlayerProfile()
        let m1 = Campaign.chapters[0].missions[0]
        let summary = profile.applyVictory(mission: m1, stars: 3, squad: [.guardian])
        XCTAssertTrue(summary.firstClear)
        XCTAssertEqual(profile.supplies, 60)
        XCTAssertEqual(profile.coins, 20)
        XCTAssertEqual(summary.unlocked, .ranger)
        XCTAssertTrue(profile.unlockedClasses.contains(.ranger))
        XCTAssertEqual(profile.xp(for: .guardian), 30)
        XCTAssertTrue(profile.isMissionUnlocked(Campaign.chapters[0].missions[1]))
        XCTAssertFalse(profile.isMissionUnlocked(Campaign.chapters[0].missions[2]))
    }

    func testReplayPaysLess() {
        var profile = PlayerProfile()
        let m1 = Campaign.chapters[0].missions[0]
        profile.applyVictory(mission: m1, stars: 1, squad: [.guardian])
        let replay = profile.applyVictory(mission: m1, stars: 3, squad: [.guardian])
        XCTAssertFalse(replay.firstClear)
        XCTAssertEqual(replay.reward.supplies, 24)
        XCTAssertEqual(profile.missionStars[m1.id], 3, "Best stars are kept")
    }

    func testFirstFiveMinutesAffordWatchtower() {
        var profile = PlayerProfile()
        profile.applyVictory(mission: Campaign.chapters[0].missions[0], stars: 3, squad: [.guardian])
        XCTAssertTrue(profile.canAfford(profile.upgradeCost(for: .watchtower)!))
        XCTAssertTrue(profile.upgrade(.watchtower))
        XCTAssertEqual(profile.level(of: .watchtower), 2)
        XCTAssertEqual(profile.squadModifiers.rangedAttackBonus, 1)
        XCTAssertEqual(profile.supplies, 0)
    }

    func testUpgradeFailsWithoutResourcesAndCapsAtMax() {
        var profile = PlayerProfile()
        XCTAssertFalse(profile.upgrade(.barracks))
        profile.supplies = 10_000
        profile.timber = 10_000
        XCTAssertTrue(profile.upgrade(.barracks))
        XCTAssertTrue(profile.upgrade(.barracks))
        XCTAssertFalse(profile.upgrade(.barracks), "Max level 3")
        XCTAssertEqual(profile.squadModifiers.bonusMaxHP, 4)
    }

    func testSupplyDepotBoostsSupplies() {
        var profile = PlayerProfile()
        profile.buildings[BuildingKind.supplyDepot.rawValue] = 3
        profile.applyVictory(mission: Campaign.chapters[0].missions[0], stars: 3, squad: [.guardian])
        XCTAssertEqual(profile.supplies, 90)
    }

    func testChapterTwoNeedsCommandCenterAndChapterOne() {
        var profile = PlayerProfile()
        let chapter2 = Campaign.chapters[1]
        XCTAssertFalse(profile.isChapterUnlocked(chapter2))
        for m in Campaign.chapters[0].missions { profile.missionStars[m.id] = 1 }
        XCTAssertFalse(profile.isChapterUnlocked(chapter2))
        XCTAssertTrue(profile.chapterNeedsCommandUpgrade(chapter2))
        profile.buildings[BuildingKind.commandCenter.rawValue] = 2
        XCTAssertTrue(profile.isChapterUnlocked(chapter2))
        XCTAssertEqual(profile.nextMission?.id, "c2m1")
    }

    func testChapterOneEconomyAffordsCommandCenter() {
        var profile = PlayerProfile()
        for m in Campaign.chapters[0].missions {
            profile.unlockedClasses = UnitClass.playerClasses
            profile.applyVictory(mission: m, stars: 3, squad: [.guardian])
        }
        profile.upgrade(.watchtower)
        XCTAssertTrue(profile.canAfford(profile.upgradeCost(for: .commandCenter)!),
                      "Supplies \(profile.supplies) timber \(profile.timber)")
    }

    func testLevelCurve() {
        XCTAssertEqual(Progression.level(forXP: 0), 1)
        XCTAssertEqual(Progression.level(forXP: 40), 2)
        XCTAssertEqual(Progression.level(forXP: 10_000), 5)
        XCTAssertEqual(Progression.xpToNext(xp: 30), 10)
        XCTAssertNil(Progression.xpToNext(xp: 10_000))
        let s = Progression.stats(for: .guardian, level: 3, modifiers: SquadModifiers(bonusMaxHP: 2))
        XCTAssertEqual(s.maxHP, 16 + 4 + 2)
        XCTAssertEqual(s.attack, 6)
        XCTAssertEqual(s.defense, 3)
    }

    func testSquadRespectsUnlocksAndSlots() {
        var profile = PlayerProfile()
        let m2 = Campaign.chapters[0].missions[1]
        XCTAssertEqual(profile.squad(for: m2).map(\.kind), [.guardian])
        profile.unlockedClasses = UnitClass.playerClasses
        XCTAssertEqual(profile.squad(for: m2).map(\.kind), [.guardian, .ranger])
        XCTAssertEqual(profile.squad(for: Campaign.chapters[0].missions[3]).count, 3)
    }
}

final class PersistenceTests: XCTestCase {
    func testProfileAndBattleRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SaveStore(directory: dir)
        defer { try? store.reset() }

        XCTAssertEqual(store.loadProfile(), PlayerProfile(), "Missing save gives a fresh profile")

        var profile = PlayerProfile()
        profile.applyVictory(mission: Campaign.chapters[0].missions[0], stars: 2, squad: [.guardian])
        profile.upgrade(.watchtower)
        profile.settings.soundOn = false
        try store.save(profile)
        XCTAssertEqual(store.loadProfile(), profile)

        var battle = BattleState(mission: Campaign.chapters[0].missions[2],
                                 squad: [SquadMember(kind: .guardian, level: 2), SquadMember(kind: .ranger, level: 1)])
        let g = battle.firstUnit(.guardian)
        battle.move(unitID: g.id, to: GridPoint(3, 4))
        try store.saveBattle(battle)
        let loaded = try XCTUnwrap(store.loadBattle())
        XCTAssertEqual(loaded.units, battle.units)
        XCTAssertEqual(loaded.structures, battle.structures)
        XCTAssertEqual(loaded.mission, battle.mission)

        try store.saveBattle(nil)
        XCTAssertNil(store.loadBattle())
    }

    func testCorruptSaveFallsBackToFreshProfile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SaveStore(directory: dir)
        defer { try? store.reset() }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("profile.json"))
        XCTAssertEqual(store.loadProfile(), PlayerProfile())
    }
}
