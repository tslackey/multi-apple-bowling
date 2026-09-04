import Foundation

/// Peak-detects a Wii-Remote-style swing from `ControllerInput` samples.
///
/// Phone is portrait, top toward the pins. Forward swing is primarily `userAcceleration.y`.
/// `buttonA` is a manual release using the peak so far (or a firm default).
public struct ThrowDetector: Sendable {
    public var playerID: UUID

    private var swinging = false
    private var peakForward = 0.0
    private var lastAttitude = Attitude.zero
    private var lastButtonA = false
    private var swingStartedAt: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0

    public init(playerID: UUID) {
        self.playerID = playerID
    }

    public mutating func ingest(_ input: ControllerInput) -> ThrowCommit? {
        lastAttitude = input.attitude
        let risingButton = input.buttonA && !lastButtonA
        lastButtonA = input.buttonA

        if input.timestamp < cooldownUntil {
            return nil
        }

        if risingButton {
            return fire(peak: max(peakForward, 1.8), at: input)
        }

        let forward = max(input.userAcceleration.y, input.userAcceleration.magnitude * 0.45)

        if !swinging, forward > 1.35 {
            swinging = true
            peakForward = forward
            swingStartedAt = input.timestamp
            return nil
        }

        guard swinging else { return nil }

        peakForward = max(peakForward, forward)

        if peakForward > 1.7, forward < 0.4 {
            return fire(peak: peakForward, at: input)
        }

        if input.timestamp - swingStartedAt > 1.25 {
            swinging = false
            peakForward = 0
        }

        return nil
    }

    public mutating func reset() {
        swinging = false
        peakForward = 0
        lastButtonA = false
        cooldownUntil = 0
    }

    private mutating func fire(peak: Double, at input: ControllerInput) -> ThrowCommit {
        swinging = false
        peakForward = 0
        cooldownUntil = input.timestamp + 0.85
        return ThrowMapper.commit(
            playerID: playerID,
            peakForwardAcceleration: peak,
            attitude: input.attitude,
            timestamp: input.timestamp
        )
    }
}
