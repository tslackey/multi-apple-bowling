import Foundation
import simd

/// Maps a committed controller throw to a one-shot ball impulse in lane space.
///
/// Lane space: +Y up, −Z toward the pins, +X right from the bowler's view.
public enum ThrowMapper: Sendable {
    public static let minSpeed: Double = 3.8
    public static let maxSpeed: Double = 10.5
    public static let maxHeading: Double = 0.24
    public static let ballRadius: Float = 0.108

    public static func commit(
        playerID: UUID,
        peakForwardAcceleration: Double,
        attitude: Attitude,
        timestamp: TimeInterval
    ) -> ThrowCommit {
        let normalized = saturate((peakForwardAcceleration - 0.9) / 3.2)
        let speed = minSpeed + (maxSpeed - minSpeed) * normalized
        let heading = clamp(attitude.yaw * 0.65, -maxHeading, maxHeading)
        let sideSpin = clamp(attitude.roll * 2.8, -8, 8)
        return ThrowCommit(
            playerID: playerID,
            speed: speed,
            heading: heading,
            sideSpin: sideSpin,
            timestamp: timestamp
        )
    }

    /// Simulator / debug throw. `power` is 0...1, `hook` is −1...1 (left...right).
    public static func debug(
        playerID: UUID,
        power: Double,
        hook: Double,
        timestamp: TimeInterval = 0
    ) -> ThrowCommit {
        let clampedPower = saturate(power)
        let clampedHook = clamp(hook, -1, 1)
        return ThrowCommit(
            playerID: playerID,
            speed: minSpeed + (maxSpeed - minSpeed) * clampedPower,
            heading: clampedHook * maxHeading,
            sideSpin: clampedHook * 6,
            timestamp: timestamp
        )
    }

    public static func laneVelocity(
        from commit: ThrowCommit
    ) -> (linear: SIMD3<Float>, angular: SIMD3<Float>) {
        let speed = Float(commit.speed)
        let heading = Float(commit.heading)
        let linear = SIMD3<Float>(sin(heading) * speed, 0, -cos(heading) * speed)
        let forwardRoll = speed / ballRadius
        let angular = SIMD3<Float>(forwardRoll, Float(commit.sideSpin), 0)
        return (linear, angular)
    }

    private static func saturate(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
