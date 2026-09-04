import Foundation
import simd
import Testing
@testable import BowlingGameCore

struct HostJoinCodeTests {
    @Test func roundTripPreservesFields() {
        let original = HostJoinCode(
            serviceName: "Slackey's Mac",
            port: 54_321,
            addresses: ["192.168.1.20", "10.0.0.8"],
            sessionID: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        )
        let parsed = HostJoinCode.parse(original.urlString)
        #expect(parsed == original)
    }

    @Test func rejectsUnknownPayload() {
        #expect(HostJoinCode.parse("https://example.com") == nil)
        #expect(HostJoinCode.parse("not a qr") == nil)
        #expect(HostJoinCode.parse("mabowl://join?n=&p=1&s=nope") == nil)
    }
}

struct LaneAimSolverTests {
    private var facingAnchor: LaneAnchorPose {
        LaneAnchorPose(
            position: .zero,
            towardBowler: SIMD3(0, 0, 1),
            screenRight: SIMD3(1, 0, 0)
        )
    }

    @Test func standingOnCenterThrowsStraight() {
        let aim = LaneAimSolver.resolve(
            phonePosition: SIMD3(0, 0, 2),
            yawDelta: 0,
            anchor: facingAnchor
        )
        #expect(abs(aim.heading) < 0.001)
        #expect(abs(aim.approachOffset) < 0.001)
    }

    @Test func standingToBowlersRightAimsRight() {
        let aim = LaneAimSolver.resolve(
            phonePosition: SIMD3(-0.6, 0, 2),
            yawDelta: 0,
            anchor: facingAnchor
        )
        #expect(aim.heading > 0)
        #expect(aim.approachOffset > 0)
    }

    @Test func turningLeftAimsLeft() {
        let aim = LaneAimSolver.resolve(
            phonePosition: SIMD3(0, 0, 2),
            yawDelta: -0.4,
            anchor: facingAnchor
        )
        #expect(aim.heading < 0)
    }

    @Test func closerQREstimatesShorterDistance() {
        let near = LaneAimSolver.estimatedDistance(
            qrNormalizedWidth: 0.4,
            imageWidth: 1920,
            focalLengthX: 1400
        )
        let far = LaneAimSolver.estimatedDistance(
            qrNormalizedWidth: 0.08,
            imageWidth: 1920,
            focalLengthX: 1400
        )
        #expect(near < far)
    }
}

struct HoldToThrowTests {
    @Test func pressDoesNotCommit() {
        var detector = ThrowDetector(playerID: UUID(), releaseMode: .holdToThrow)
        let press = ControllerInput(
            timestamp: 1,
            attitude: .zero,
            userAcceleration: Acceleration(x: 0, y: 3, z: 0),
            buttonA: true
        )
        #expect(detector.ingest(press) == nil)
    }

    @Test func releaseAfterSwingCommitsPeak() {
        var detector = ThrowDetector(playerID: UUID(), releaseMode: .holdToThrow)
        let holdSoft = ControllerInput(
            timestamp: 1,
            attitude: .zero,
            userAcceleration: Acceleration(x: 0, y: 1.2, z: 0),
            buttonA: true
        )
        let holdHard = ControllerInput(
            timestamp: 1.1,
            attitude: Attitude(pitch: 0, yaw: -0.2, roll: 0.1),
            userAcceleration: Acceleration(x: 0, y: 3.4, z: 0),
            buttonA: true
        )
        let release = ControllerInput(
            timestamp: 1.2,
            attitude: holdHard.attitude,
            userAcceleration: Acceleration(x: 0, y: 0.2, z: 0),
            buttonA: false
        )
        #expect(detector.ingest(holdSoft) == nil)
        #expect(detector.ingest(holdHard) == nil)
        let commit = detector.ingest(release)
        #expect(commit != nil)
        #expect(commit!.speed > ThrowMapper.minSpeed)
    }

    @Test func automaticSwingDoesNotFireWhileHoldingMode() {
        var detector = ThrowDetector(playerID: UUID(), releaseMode: .holdToThrow)
        var commit: ThrowCommit?
        let profile: [(TimeInterval, Double)] = [
            (0.00, 0.1),
            (0.10, 1.6),
            (0.22, 3.1),
            (0.34, 0.2),
        ]
        for (time, y) in profile {
            let sample = ControllerInput(
                timestamp: time,
                attitude: .zero,
                userAcceleration: Acceleration(x: 0, y: y, z: 0),
                buttonA: false
            )
            if let result = detector.ingest(sample) {
                commit = result
            }
        }
        #expect(commit == nil)
    }

    @Test func laneAimOverridesGyroHeading() {
        var detector = ThrowDetector(playerID: UUID(), releaseMode: .holdToThrow)
        let hold = ControllerInput(
            timestamp: 1,
            attitude: Attitude(pitch: 0, yaw: 0.4, roll: 0),
            userAcceleration: Acceleration(x: 0, y: 2.5, z: 0),
            buttonA: true
        )
        let release = ControllerInput(
            timestamp: 1.2,
            attitude: hold.attitude,
            userAcceleration: .zero,
            buttonA: false
        )
        _ = detector.ingest(hold)
        let aim = LaneAim(heading: -0.12, approachOffset: -0.2)
        let commit = detector.ingest(release, aim: aim)
        #expect(commit?.heading == -0.12)
        #expect(commit?.approachOffset == -0.2)
    }
}

struct ThrowCommitDecodingTests {
    @Test func missingApproachOffsetDefaultsToZero() throws {
        let payload = """
        {"playerID":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","speed":6.1,"heading":0.1,"sideSpin":1.2,"timestamp":3}
        """
        let commit = try JSONDecoder().decode(ThrowCommit.self, from: Data(payload.utf8))
        #expect(commit.approachOffset == 0)
        #expect(commit.speed == 6.1)
    }
}
