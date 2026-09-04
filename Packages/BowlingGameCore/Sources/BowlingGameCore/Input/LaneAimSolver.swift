import Foundation
import simd

/// World pose of the host QR / screen in ARKit space.
///
/// +Y is world up. `towardBowler` points out of the screen. `screenRight` is the TV's right
/// (the bowler's left).
public struct LaneAnchorPose: Sendable, Equatable {
    public var position: SIMD3<Float>
    public var towardBowler: SIMD3<Float>
    public var screenRight: SIMD3<Float>

    public init(position: SIMD3<Float>, towardBowler: SIMD3<Float>, screenRight: SIMD3<Float>) {
        self.position = position
        self.towardBowler = towardBowler
        self.screenRight = screenRight
    }

    public func localPoint(_ world: SIMD3<Float>) -> SIMD3<Float> {
        let rel = world - position
        let up = SIMD3<Float>(0, 1, 0)
        return SIMD3(
            simd_dot(rel, screenRight),
            simd_dot(rel, up),
            simd_dot(rel, towardBowler)
        )
    }
}

/// Lane-space aim derived from the phone's pose relative to the QR anchor.
public struct LaneAim: Sendable, Equatable {
    /// Radians. 0 is straight; negative is left from the bowler's view.
    public var heading: Double
    /// Meters. Positive is right from the bowler's view.
    public var approachOffset: Double

    public init(heading: Double, approachOffset: Double) {
        self.heading = heading
        self.approachOffset = approachOffset
    }
}

/// Turns a recorded QR world pose plus the phone's current pose into a lane heading.
public enum LaneAimSolver: Sendable {
    public static let assumedQRWidth: Float = 0.16
    public static let maxApproachOffset: Double = 0.38

    public static func estimatedDistance(
        qrNormalizedWidth: Float,
        imageWidth: Float,
        focalLengthX: Float,
        physicalWidth: Float = assumedQRWidth
    ) -> Float {
        let pixelWidth = max(qrNormalizedWidth * imageWidth, 8)
        let distance = physicalWidth * focalLengthX / pixelWidth
        return min(6, max(0.4, distance))
    }

    /// Places the QR on the camera look ray, facing the phone.
    public static func poseFacingCamera(
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>,
        distance: Float
    ) -> LaneAnchorPose {
        let forward = simd_normalize(cameraForward)
        let position = cameraPosition + forward * distance
        let worldUp = SIMD3<Float>(0, 1, 0)
        var towardBowler = cameraPosition - position
        towardBowler.y = 0
        if simd_length(towardBowler) < 0.05 {
            towardBowler = -SIMD3(forward.x, 0, forward.z)
        }
        towardBowler = simd_normalize(towardBowler)
        var screenRight = simd_cross(worldUp, towardBowler)
        if simd_length(screenRight) < 0.05 {
            screenRight = SIMD3(1, 0, 0)
        } else {
            screenRight = simd_normalize(screenRight)
        }
        return LaneAnchorPose(
            position: position,
            towardBowler: towardBowler,
            screenRight: screenRight
        )
    }

    public static func resolve(
        phonePosition: SIMD3<Float>,
        yawDelta: Double,
        anchor: LaneAnchorPose
    ) -> LaneAim {
        let local = anchor.localPoint(phonePosition)
        let stanceZ = max(Double(local.z), 0.2)
        let stanceHeading = atan2(Double(-local.x), stanceZ)
        let yawHeading = yawDelta * 0.65
        let heading = clamp(
            stanceHeading * 0.55 + yawHeading * 0.45,
            -ThrowMapper.maxHeading,
            ThrowMapper.maxHeading
        )
        let approachOffset = clamp(Double(-local.x) * 0.35, -maxApproachOffset, maxApproachOffset)
        return LaneAim(heading: heading, approachOffset: approachOffset)
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
