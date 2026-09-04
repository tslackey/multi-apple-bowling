import Foundation

/// A finished throw. The host applies this once as a ball impulse — never as a per-tick stream.
public struct ThrowCommit: Codable, Sendable, Equatable {
    public var playerID: UUID
    /// Lane-space speed in meters per second.
    public var speed: Double
    /// Radians. 0 is straight down the lane; negative is left from the bowler's view.
    public var heading: Double
    /// Radians per second around the vertical axis (hook).
    public var sideSpin: Double
    public var timestamp: TimeInterval

    public init(
        playerID: UUID,
        speed: Double,
        heading: Double,
        sideSpin: Double,
        timestamp: TimeInterval
    ) {
        self.playerID = playerID
        self.speed = speed
        self.heading = heading
        self.sideSpin = sideSpin
        self.timestamp = timestamp
    }
}
