import Foundation

/// A tile coordinate on the tactical grid. `x` grows to the right, `y` grows downward
/// (row 0 is the top of the portrait screen, where enemies usually start).
public struct GridPoint: Hashable, Codable, Comparable, CustomStringConvertible, Sendable {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    /// Orthogonal neighbours. Order is fixed so every search is deterministic.
    public var neighbors: [GridPoint] {
        [GridPoint(x, y - 1), GridPoint(x + 1, y), GridPoint(x, y + 1), GridPoint(x - 1, y)]
    }

    public func distance(to other: GridPoint) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }

    public static func < (lhs: GridPoint, rhs: GridPoint) -> Bool {
        lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
    }

    public var description: String { "(\(x),\(y))" }
}
