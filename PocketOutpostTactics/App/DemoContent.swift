import Foundation
import GameCore

/// Deterministic sample progress used only for App Store screenshots (`-screenshot <scene>`).
enum DemoContent {
    static func profile(for scene: String) -> PlayerProfile {
        var p = PlayerProfile()
        p.unlockedClasses = UnitClass.playerClasses
        let cleared = scene == "title" ? 0 : 7
        for m in Campaign.chapters[0].missions.prefix(cleared) {
            p.missionStars[m.id] = m.index % 3 == 0 ? 2 : 3
        }
        p.classXP = ["guardian": 240, "ranger": 200, "scout": 120, "engineer": 60]
        p.buildings = ["watchtower": 3, "barracks": 2, "workshop": 2, "supplyDepot": 2, "commandCenter": 2]
        p.coins = 420
        p.supplies = 315
        p.timber = 96
        p.ownedCosmetics = ["forest"]
        p.counters = ["battlesWon": 9, "upgrades": 6]
        p.seenTips = ["all"]
        return p
    }

    static func battleMission(for scene: String) -> MissionDefinition {
        switch scene {
        case "ranged": return Campaign.chapters[0].missions[5]
        default: return Campaign.chapters[0].missions[6]
        }
    }
}
