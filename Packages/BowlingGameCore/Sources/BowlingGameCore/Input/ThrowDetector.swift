import Foundation

/// How a swing becomes a `ThrowCommit`.
public enum ThrowReleaseMode: String, Sendable, Equatable, CaseIterable {
    /// Peak-detect the swing, or tap `buttonA` to release immediately.
    case automatic
    /// Hold `buttonA`, swing, release to throw.
    case holdToThrow
}

/// Peak-detects a Wii-Remote-style swing from `ControllerInput` samples.
///
/// Phone is portrait, top toward the pins. Forward swing is primarily `userAcceleration.y`.
/// `buttonA` is a manual release using the peak so far (or a firm default).
public struct ThrowDetector: Sendable {
    public var playerID: UUID
    public var releaseMode: ThrowReleaseMode = .automatic

    private var swinging = false
    private var peakForward = 0.0
    private var lastAttitude = Attitude.zero
    private var lastButtonA = false
    private var swingStartedAt: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0

    public init(playerID: UUID, releaseMode: ThrowReleaseMode = .automatic) {
        self.playerID = playerID
        self.releaseMode = releaseMode
    }

    public mutating func ingest(_ input: ControllerInput, aim: LaneAim? = nil) -> ThrowCommit? {
        lastAttitude = input.attitude
        let risingButton = input.buttonA && !lastButtonA
        let fallingButton = !input.buttonA && lastButtonA
        lastButtonA = input.buttonA

        if input.timestamp < cooldownUntil {
            return nil
        }

        switch releaseMode {
        case .automatic:
            return ingestAutomatic(input, risingButton: risingButton, aim: aim)
        case .holdToThrow:
            return ingestHold(input, fallingButton: fallingButton, aim: aim)
        }
    }

    public mutating func reset() {
        swinging = false
        peakForward = 0
        lastButtonA = false
        cooldownUntil = 0
    }

    private mutating func ingestAutomatic(
        _ input: ControllerInput,
        risingButton: Bool,
        aim: LaneAim?
    ) -> ThrowCommit? {
        if risingButton {
            return fire(peak: max(peakForward, 1.8), at: input, aim: aim)
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
            return fire(peak: peakForward, at: input, aim: aim)
        }

        if input.timestamp - swingStartedAt > 1.25 {
            swinging = false
            peakForward = 0
        }

        return nil
    }

    private mutating func ingestHold(
        _ input: ControllerInput,
        fallingButton: Bool,
        aim: LaneAim?
    ) -> ThrowCommit? {
        if input.buttonA {
            let forward = max(input.userAcceleration.y, input.userAcceleration.magnitude * 0.45)
            peakForward = max(peakForward, forward)
            swinging = true
            return nil
        }

        guard fallingButton else { return nil }
        return fire(peak: max(peakForward, 1.8), at: input, aim: aim)
    }

    private mutating func fire(peak: Double, at input: ControllerInput, aim: LaneAim?) -> ThrowCommit {
        swinging = false
        peakForward = 0
        cooldownUntil = input.timestamp + 0.85
        return ThrowMapper.commit(
            playerID: playerID,
            peakForwardAcceleration: peak,
            attitude: input.attitude,
            timestamp: input.timestamp,
            aim: aim
        )
    }
}
