import Foundation
@testable import GameCore

func makeMission(_ rows: [String], objective: Objective = .eliminate, reinforcements: [Reinforcement] = [],
                 allowed: [UnitClass]? = nil) -> MissionDefinition {
    MissionDefinition(id: "test", chapter: 1, index: 1, title: "Test", briefing: "", biome: .forest,
                      objective: objective, rows: rows, reinforcements: reinforcements,
                      reward: Reward(coins: 10, supplies: 50, timber: 10, xp: 20), parRounds: 3,
                      allowedClasses: allowed)
}

func makeBattle(_ rows: [String], squad: [UnitClass], objective: Objective = .eliminate,
                reinforcements: [Reinforcement] = [], level: Int = 1,
                modifiers: SquadModifiers = .none) -> BattleState {
    BattleState(mission: makeMission(rows, objective: objective, reinforcements: reinforcements),
                squad: squad.map { SquadMember(kind: $0, level: level) }, modifiers: modifiers)
}

extension BattleState {
    func firstUnit(_ kind: UnitClass) -> BattleUnit {
        units.first { $0.kind == kind && $0.isAlive }!
    }

    mutating func place(_ id: Int, at p: GridPoint) {
        let i = units.firstIndex { $0.id == id }!
        units[i].position = p
    }

    mutating func setHP(_ id: Int, _ hp: Int) {
        let i = units.firstIndex { $0.id == id }!
        units[i].hp = hp
    }
}
