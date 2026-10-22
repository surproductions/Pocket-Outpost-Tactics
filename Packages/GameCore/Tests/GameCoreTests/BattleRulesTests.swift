import XCTest
@testable import GameCore

final class MovementTests: XCTestCase {
    func testGuardianMovesThreeTilesOnOpenGround() {
        let battle = makeBattle([
            ".......",
            ".......",
            "...1...",
            ".......",
            "r......",
        ], squad: [.guardian])
        let g = battle.firstUnit(.guardian)
        let reach = battle.reachableTiles(for: g.id)
        XCTAssertNotNil(reach[GridPoint(3, 5 - 5)], "3 tiles straight up should be reachable")
        XCTAssertEqual(reach[GridPoint(6, 2)], 3)
        XCTAssertNil(reach[GridPoint(3, 6)], "Off the map")
        XCTAssertNil(reach[GridPoint(0, 0)], "4+ tiles away")
        XCTAssertTrue(reach.values.allSatisfy { $0 <= 3 })
    }

    func testForestCostsTwoAndRocksBlock() {
        let battle = makeBattle([
            "r......",
            ".......",
            ".RFR...",
            ".R1R...",
            ".RRR...",
        ], squad: [.guardian])
        let g = battle.firstUnit(.guardian)
        let reach = battle.reachableTiles(for: g.id)
        XCTAssertEqual(reach[GridPoint(2, 2)], 2, "Forest costs 2")
        XCTAssertEqual(reach[GridPoint(2, 1)], 3)
        XCTAssertNil(reach[GridPoint(2, 0)], "Would cost 4")
        XCTAssertNil(reach[GridPoint(1, 3)], "Boulders are impassable")
    }

    func testCannotPassThroughEnemiesButCanPassAllies() {
        var battle = makeBattle([
            "...r...",
            ".......",
            ".......",
            "R.RrR.R",
            "RR.1.RR",
            "RRR2RRR",
        ], squad: [.guardian, .ranger])
        let ranger = battle.firstUnit(.ranger)
        let guardian = battle.firstUnit(.guardian)
        let reach = battle.reachableTiles(for: ranger.id)
        XCTAssertNil(reach[guardian.position], "Can't stop on an ally")
        XCTAssertNotNil(reach[GridPoint(2, 4)], "Can walk through the ally")
        XCTAssertNil(reach[GridPoint(3, 2)], "Enemy blocks the corridor")

        battle.move(unitID: guardian.id, to: GridPoint(2, 4))
        XCTAssertEqual(battle.unit(id: guardian.id)?.position, GridPoint(2, 4))
        XCTAssertEqual(battle.unit(id: guardian.id)?.movePoints, 2)
    }

    func testMoveRejectsUnreachableTile() {
        var battle = makeBattle(["r......", ".......", ".......", "...1..."], squad: [.guardian])
        let g = battle.firstUnit(.guardian)
        let events = battle.move(unitID: g.id, to: GridPoint(0, 0))
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(battle.unit(id: g.id)?.position, GridPoint(3, 3))
    }
}

final class CombatTests: XCTestCase {
    func testRangerRangeExcludesAdjacentTiles() {
        var battle = makeBattle([
            ".......",
            "...r...",
            "...2...",
            ".......",
        ], squad: [.ranger])
        let ranger = battle.firstUnit(.ranger)
        XCTAssertTrue(battle.targets(for: ranger.id).isEmpty, "Adjacent enemy can't be shot")
        battle.place(ranger.id, at: GridPoint(3, 3))
        XCTAssertEqual(battle.targets(for: ranger.id), [GridPoint(3, 1)])
    }

    func testDamageFormulaWithDefenseAndCover() {
        var battle = makeBattle([
            ".F.....",
            ".1.....",
            ".......",
            "....r..",
        ], squad: [.guardian])
        let guardian = battle.firstUnit(.guardian)
        let raider = battle.firstUnit(.raider)
        battle.place(raider.id, at: GridPoint(1, 2))
        // Guardian attack 5 - raider defense 0 = 5
        XCTAssertEqual(battle.damagePreview(attackerID: guardian.id, target: GridPoint(1, 2)), 5)
        battle.place(raider.id, at: GridPoint(1, 0))
        // Forest cover -1
        XCTAssertEqual(battle.damagePreview(attackerID: guardian.id, target: GridPoint(1, 0)), 4)
        // Raider attack 4 - guardian defense 2 = 2
        XCTAssertEqual(battle.damagePreview(attackerID: raider.id, target: guardian.position), 2)
    }

    func testDamageIsAtLeastOne() {
        var battle = makeBattle(["1r....."], squad: [.engineer])
        let raider = battle.firstUnit(.raider)
        let engineer = battle.firstUnit(.engineer)
        var stats = battle.units.first { $0.id == raider.id }!.stats
        stats.defense = 10
        let i = battle.units.firstIndex { $0.id == raider.id }!
        battle.units[i].stats = stats
        XCTAssertEqual(battle.damagePreview(attackerID: engineer.id, target: raider.position), 1)
    }

    func testHighGroundBonusForRangedOnly() {
        let battle = makeBattle([
            "...r...",
            ".......",
            "...H...",
            "2......",
        ], squad: [.ranger])
        var b = battle
        let ranger = b.firstUnit(.ranger)
        b.place(ranger.id, at: GridPoint(3, 2))
        XCTAssertEqual(b.damagePreview(attackerID: ranger.id, target: GridPoint(3, 0)), 6, "5 attack +1 high ground")
    }

    func testScoutFlankBonus() {
        var battle = makeBattle([
            ".......",
            "..1r3..",
            ".......",
        ], squad: [.guardian, .scout])
        let scout = battle.firstUnit(.scout)
        let raider = battle.firstUnit(.raider)
        XCTAssertEqual(battle.damagePreview(attackerID: scout.id, target: raider.position), 6, "4 attack +2 flank")
        let guardian = battle.firstUnit(.guardian)
        battle.place(guardian.id, at: GridPoint(0, 2))
        XCTAssertEqual(battle.damagePreview(attackerID: scout.id, target: raider.position), 4)
    }

    func testAttackKillsAndTriggersVictory() {
        var battle = makeBattle([".1r...."], squad: [.guardian])
        let guardian = battle.firstUnit(.guardian)
        let raider = battle.firstUnit(.raider)
        battle.setHP(raider.id, 3)
        let events = battle.attack(unitID: guardian.id, target: raider.position)
        XCTAssertTrue(events.contains(.unitDefeated(unitID: raider.id)))
        XCTAssertEqual(battle.phase, .victory)
        XCTAssertEqual(battle.stars, 3)
    }

    func testCannotAttackTwice() {
        var battle = makeBattle([".1r...."], squad: [.guardian])
        let guardian = battle.firstUnit(.guardian)
        let raider = battle.firstUnit(.raider)
        battle.attack(unitID: guardian.id, target: raider.position)
        XCTAssertTrue(battle.attack(unitID: guardian.id, target: raider.position).isEmpty)
        XCTAssertEqual(battle.unit(id: raider.id)?.hp, 3)
    }
}

final class AbilityTests: XCTestCase {
    func testShieldWallReducesDamageAndExpires() {
        var battle = makeBattle([
            "...r...",
            "...1...",
            "...2...",
        ], squad: [.guardian, .ranger])
        let guardian = battle.firstUnit(.guardian)
        let raider = battle.firstUnit(.raider)
        let ranger = battle.firstUnit(.ranger)
        XCTAssertEqual(battle.damagePreview(attackerID: raider.id, target: guardian.position), 2)
        battle.useAbility(unitID: guardian.id)
        XCTAssertEqual(battle.damagePreview(attackerID: raider.id, target: guardian.position), 1, "+2 defense, min 1")
        battle.place(raider.id, at: GridPoint(2, 2))
        XCTAssertEqual(battle.damagePreview(attackerID: raider.id, target: ranger.position), 3, "Adjacent ally takes 1 less")
        XCTAssertEqual(battle.unit(id: guardian.id)?.abilityCooldown, 3)

        battle.endPlayerTurn()
        battle.endEnemyTurn()
        XCTAssertFalse(battle.unit(id: guardian.id)!.has(.shielded), "Shield lasts until your next turn")
        XCTAssertEqual(battle.unit(id: guardian.id)?.abilityCooldown, 2, "Cooldown ticks at turn start")
    }

    func testPrecisionShotIgnoresCover() {
        var battle = makeBattle([
            "...F...",
            ".......",
            ".......",
            ".......",
            "...2...",
        ], squad: [.ranger])
        let ranger = battle.firstUnit(.ranger)
        let enemyID = battle.nextUnitID
        battle.units.append(BattleUnit(id: enemyID, kind: .raider, position: GridPoint(3, 0)))
        XCTAssertEqual(battle.damagePreview(attackerID: ranger.id, target: GridPoint(3, 0), ability: .precisionShot), 7)
        XCTAssertTrue(battle.targets(for: ranger.id).isEmpty, "Normal range is 3")
        XCTAssertEqual(battle.targets(for: ranger.id, ability: .precisionShot), [GridPoint(3, 0)])
        let events = battle.useAbility(unitID: ranger.id, target: GridPoint(3, 0))
        XCTAssertTrue(events.contains(.attacked(attackerID: ranger.id, target: GridPoint(3, 0), damage: 7, ability: .precisionShot)))
        XCTAssertEqual(battle.unit(id: enemyID)?.hp, 1)
    }

    func testDashKeepsMovementAfterAttacking() {
        var battle = makeBattle([".3r...."], squad: [.scout])
        let scout = battle.firstUnit(.scout)
        let raider = battle.firstUnit(.raider)
        battle.useAbility(unitID: scout.id)
        XCTAssertEqual(battle.unit(id: scout.id)?.movePoints, 8)
        battle.attack(unitID: scout.id, target: raider.position)
        XCTAssertEqual(battle.unit(id: scout.id)?.movePoints, 8, "Dash keeps leftover movement")
        XCTAssertFalse(battle.reachableTiles(for: scout.id).isEmpty)
    }

    func testFieldKitBuildsAndRepairs() {
        var battle = makeBattle([
            "r......",
            ".......",
            "...4...",
            "...1...",
        ], squad: [.guardian, .engineer])
        let engineer = battle.firstUnit(.engineer)
        let guardian = battle.firstUnit(.guardian)
        battle.useAbility(unitID: engineer.id, target: GridPoint(3, 1))
        XCTAssertEqual(battle.structures[GridPoint(3, 1)]?.kind, .barricade)
        XCTAssertEqual(battle.structures[GridPoint(3, 1)]?.hp, 6)

        var second = makeBattle(["r......", "...4...", "...1..."], squad: [.guardian, .engineer],
                                modifiers: SquadModifiers(engineerBonus: 1))
        let g2 = second.firstUnit(.guardian)
        second.setHP(g2.id, 5)
        second.useAbility(unitID: second.firstUnit(.engineer).id, target: g2.position)
        XCTAssertEqual(second.unit(id: g2.id)?.hp, 10, "Repairs 4 + workshop bonus 1")
        _ = guardian
    }

    func testBarricadeGrantsAdjacentCover() {
        var battle = makeBattle([
            "r......",
            ".......",
            "...B...",
            "...1...",
        ], squad: [.guardian])
        XCTAssertEqual(battle.coverBonus(at: GridPoint(3, 3)), 1)
        XCTAssertEqual(battle.coverBonus(at: GridPoint(0, 0)), 0)
        battle.structures[GridPoint(3, 2)] = nil
        XCTAssertEqual(battle.coverBonus(at: GridPoint(3, 3)), 0)
    }
}

final class TurnAndObjectiveTests: XCTestCase {
    func testTurnCycleResetsUnits() {
        var battle = makeBattle(["r......", ".......", ".......", "...1..."], squad: [.guardian])
        let g = battle.firstUnit(.guardian)
        battle.move(unitID: g.id, to: GridPoint(3, 1))
        battle.wait(unitID: g.id)
        XCTAssertTrue(battle.playerTurnFinished)
        battle.endPlayerTurn()
        XCTAssertEqual(battle.phase, .enemy)
        XCTAssertTrue(battle.move(unitID: g.id, to: GridPoint(3, 2)).isEmpty, "Player can't act in enemy phase")
        battle.endEnemyTurn()
        XCTAssertEqual(battle.phase, .player)
        XCTAssertEqual(battle.round, 2)
        XCTAssertEqual(battle.unit(id: g.id)?.movePoints, 3)
        XCTAssertEqual(battle.unit(id: g.id)?.hasActed, false)
    }

    func testDefendVictoryAfterRounds() {
        var battle = makeBattle([
            "r......",
            ".......",
            ".......",
            "...1...",
            "...G...",
        ], squad: [.guardian], objective: .defend(rounds: 2))
        for _ in 0..<2 {
            battle.endPlayerTurn()
            battle.endEnemyTurn()
        }
        XCTAssertEqual(battle.phase, .victory)
    }

    func testGateDestroyedIsDefeat() {
        var battle = makeBattle([
            "...b...",
            "...G...",
            ".......",
            "1......",
        ], squad: [.guardian], objective: .defend(rounds: 5))
        battle.structures[GridPoint(3, 1)]?.hp = 3
        battle.endPlayerTurn()
        let brute = battle.firstUnit(.brute)
        let events = battle.attack(unitID: brute.id, target: GridPoint(3, 1))
        XCTAssertTrue(events.contains(.structureDestroyed(at: GridPoint(3, 1))))
        XCTAssertEqual(battle.phase, .defeat)
    }

    func testBruteDoublesStructureDamage() {
        var battle = makeBattle(["...b...", "...B...", ".......", "1......"], squad: [.guardian])
        let brute = battle.firstUnit(.brute)
        XCTAssertEqual(battle.damagePreview(attackerID: brute.id, target: GridPoint(3, 1)), 8, "6x2 capped at barricade HP")
    }

    func testAllPlayersDefeatedIsDefeat() {
        var battle = makeBattle(["1r....."], squad: [.ranger])
        let ranger = battle.firstUnit(.ranger)
        battle.setHP(ranger.id, 1)
        battle.endPlayerTurn()
        TacticalAI.playPhase(&battle)
        XCTAssertEqual(battle.phase, .defeat)
    }

    func testReinforcementsArriveAndBlockEarlyVictory() {
        var battle = makeBattle([".......", ".......", ".1r...."], squad: [.guardian],
                                reinforcements: [Reinforcement(round: 1, kind: .raider, position: GridPoint(0, 0))])
        let guardian = battle.firstUnit(.guardian)
        let raider = battle.firstUnit(.raider)
        battle.setHP(raider.id, 1)
        battle.attack(unitID: guardian.id, target: raider.position)
        XCTAssertEqual(battle.phase, .player, "Pending reinforcements prevent victory")
        let events = battle.endPlayerTurn()
        XCTAssertTrue(events.contains { if case .reinforcementsArrived = $0 { return true } else { return false } })
        XCTAssertEqual(battle.units(of: .enemy).count, 1)
    }

    func testStarsReflectLossesAndPar() {
        var battle = makeBattle([".1r...."], squad: [.guardian])
        battle.round = 10
        battle.playerUnitsLost = 1
        battle.phase = .victory
        XCTAssertEqual(battle.stars, 1)
    }
}
