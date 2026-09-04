import Foundation
import Testing
@testable import BowlingGameCore

struct ThrowMapperTests {
    @Test func debugStraightThrowGoesDownLane() {
        let commit = ThrowMapper.debug(playerID: UUID(), power: 0.5, hook: 0)
        let velocity = ThrowMapper.laneVelocity(from: commit)
        #expect(commit.heading == 0)
        #expect(velocity.linear.x == 0)
        #expect(velocity.linear.z < 0)
        #expect(commit.speed > ThrowMapper.minSpeed)
        #expect(commit.speed < ThrowMapper.maxSpeed)
    }

    @Test func rightHookAimsRight() {
        let commit = ThrowMapper.debug(playerID: UUID(), power: 1, hook: 1)
        #expect(commit.heading > 0)
        #expect(commit.sideSpin > 0)
        #expect(commit.speed == ThrowMapper.maxSpeed)
    }

    @Test func motionCommitUsesPeakAcceleration() {
        let soft = ThrowMapper.commit(
            playerID: UUID(),
            peakForwardAcceleration: 1.0,
            attitude: .zero,
            timestamp: 0
        )
        let hard = ThrowMapper.commit(
            playerID: UUID(),
            peakForwardAcceleration: 4.0,
            attitude: .zero,
            timestamp: 0
        )
        #expect(hard.speed > soft.speed)
    }
}

struct ThrowDetectorTests {
    @Test func swingPeakThenDropCommits() {
        var detector = ThrowDetector(playerID: UUID())
        var commit: ThrowCommit?
        for sample in swingSamples() {
            if let result = detector.ingest(sample) {
                commit = result
            }
        }
        #expect(commit != nil)
        #expect(commit!.speed > ThrowMapper.minSpeed)
    }

    @Test func buttonAReleases() {
        var detector = ThrowDetector(playerID: UUID())
        let idle = ControllerInput(
            timestamp: 1,
            attitude: .zero,
            userAcceleration: .zero,
            buttonA: false
        )
        #expect(detector.ingest(idle) == nil)
        let press = ControllerInput(
            timestamp: 1.1,
            attitude: Attitude(pitch: 0, yaw: 0.1, roll: 0),
            userAcceleration: .zero,
            buttonA: true
        )
        #expect(detector.ingest(press) != nil)
    }

    private func swingSamples() -> [ControllerInput] {
        let profile: [(TimeInterval, Double)] = [
            (0.00, 0.1),
            (0.05, 0.4),
            (0.10, 1.6),
            (0.16, 2.8),
            (0.22, 3.1),
            (0.28, 1.2),
            (0.34, 0.2),
        ]
        return profile.map { time, y in
            ControllerInput(
                timestamp: time,
                attitude: .zero,
                userAcceleration: Acceleration(x: 0, y: y, z: 0),
                buttonA: false
            )
        }
    }
}

struct MessageFramingTests {
    @Test func roundTripSplitAcrossPackets() throws {
        let message = NetworkMessage.throwCommit(
            ThrowMapper.debug(playerID: UUID(), power: 0.8, hook: -0.2, timestamp: 12)
        )
        let framed = try MessageAssembler.frame(message)
        var assembler = MessageAssembler()
        let mid = framed.count / 2
        let first = try assembler.append(framed.prefix(mid))
        #expect(first.isEmpty)
        let second = try assembler.append(framed.suffix(from: mid))
        #expect(second == [message])
    }
}
