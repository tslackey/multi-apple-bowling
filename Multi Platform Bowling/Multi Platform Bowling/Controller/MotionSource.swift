#if os(iOS)
import Foundation
import CoreMotion
import Observation
import BowlingGameCore

/// Core Motion samples for a Wii-Remote-style hold. UI meter updates are throttled;
/// throw detection still sees every sample.
@Observable
@MainActor
final class MotionSource {
    var onSample: ((ControllerInput) -> Void)?
    var motionError: String?
    private(set) var swingLevel = 0.0
    private(set) var isRunning = false

    private let manager = CMMotionManager()
    private var lastUIUpdate: TimeInterval = 0

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    func start() {
        stop()
        motionError = nil
        guard manager.isDeviceMotionAvailable else {
            motionError = "This device has no motion sensors. Use Throw now."
            return
        }
        isRunning = true
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                self.motionError = error.localizedDescription
                return
            }
            guard let motion else { return }
            let attitude = motion.attitude
            let accel = motion.userAcceleration
            let input = ControllerInput(
                timestamp: motion.timestamp,
                attitude: Attitude(pitch: attitude.pitch, yaw: attitude.yaw, roll: attitude.roll),
                userAcceleration: Acceleration(x: accel.x, y: accel.y, z: accel.z),
                buttonA: false
            )
            self.onSample?(input)
            if motion.timestamp - self.lastUIUpdate > 0.08 {
                self.lastUIUpdate = motion.timestamp
                let forward = max(accel.y, input.userAcceleration.magnitude * 0.45)
                self.swingLevel = min(1, max(0, forward / 3.0))
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
        swingLevel = 0
        lastUIUpdate = 0
    }
}
#endif
