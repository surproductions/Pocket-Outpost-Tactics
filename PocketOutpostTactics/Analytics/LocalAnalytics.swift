import Foundation
import GameCore

/// On-device only. The game has no analytics SDK and makes no network requests; these numbers
/// power the "Your Journey" panel and can be surfaced to a future opt-in analytics service.
enum LocalAnalytics {
    struct Summary {
        var battlesWon: Int
        var battlesLost: Int
        var stars: Int
        var upgrades: Int
        var daysPlayed: Int
        var returnedDay1: Bool
        var returnedDay7: Bool
        var returnedDay30: Bool
    }

    static func summary(for profile: PlayerProfile) -> Summary {
        let marks = profile.retentionMarks
        return Summary(
            battlesWon: profile.counters["battlesWon"] ?? 0,
            battlesLost: profile.counters["battlesLost"] ?? 0,
            stars: profile.totalStars,
            upgrades: profile.counters["upgrades"] ?? 0,
            daysPlayed: profile.playDays.count,
            returnedDay1: marks.d1,
            returnedDay7: marks.d7,
            returnedDay30: marks.d30)
    }
}
