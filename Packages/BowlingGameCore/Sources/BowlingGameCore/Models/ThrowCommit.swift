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
    /// Meters. Positive shifts the ball right from the bowler's view.
    public var approachOffset: Double

    public init(
        playerID: UUID,
        speed: Double,
        heading: Double,
        sideSpin: Double,
        timestamp: TimeInterval,
        approachOffset: Double = 0
    ) {
        self.playerID = playerID
        self.speed = speed
        self.heading = heading
        self.sideSpin = sideSpin
        self.timestamp = timestamp
        self.approachOffset = approachOffset
    }

    enum CodingKeys: String, CodingKey {
        case playerID, speed, heading, sideSpin, timestamp, approachOffset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerID = try container.decode(UUID.self, forKey: .playerID)
        speed = try container.decode(Double.self, forKey: .speed)
        heading = try container.decode(Double.self, forKey: .heading)
        sideSpin = try container.decode(Double.self, forKey: .sideSpin)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        approachOffset = try container.decodeIfPresent(Double.self, forKey: .approachOffset) ?? 0
    }
}
