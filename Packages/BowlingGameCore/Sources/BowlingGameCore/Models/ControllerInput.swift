import Foundation

/// Device attitude in radians (Core Motion convention: pitch, yaw, roll).
public struct Attitude: Codable, Sendable, Equatable {
    public var pitch: Double
    public var yaw: Double
    public var roll: Double

    public init(pitch: Double, yaw: Double, roll: Double) {
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
    }

    public static let zero = Attitude(pitch: 0, yaw: 0, roll: 0)
}

/// User acceleration in g's, device coordinates (gravity already removed).
public struct Acceleration: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    public static let zero = Acceleration(x: 0, y: 0, z: 0)
}

/// One motion sample from a phone or watch controller.
///
/// Held like a Wii Remote: portrait, top of the device toward the pins.
/// Forward swing is primarily `userAcceleration.y`.
public struct ControllerInput: Codable, Sendable, Equatable {
    public var timestamp: TimeInterval
    public var attitude: Attitude
    public var userAcceleration: Acceleration
    public var buttonA: Bool

    public init(
        timestamp: TimeInterval,
        attitude: Attitude,
        userAcceleration: Acceleration,
        buttonA: Bool
    ) {
        self.timestamp = timestamp
        self.attitude = attitude
        self.userAcceleration = userAcceleration
        self.buttonA = buttonA
    }
}
