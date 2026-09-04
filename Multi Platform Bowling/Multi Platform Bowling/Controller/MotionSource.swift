#if os(iOS)
import Foundation
import CoreMotion
import BowlingGameCore

@MainActor
final class MotionSource {
    var onSample: ((ControllerInput) -> Void)?

    private let manager = CMMotionManager()

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let attitude = motion.attitude
            let accel = motion.userAcceleration
            self?.onSample?(
                ControllerInput(
                    timestamp: motion.timestamp,
                    attitude: Attitude(pitch: attitude.pitch, yaw: attitude.yaw, roll: attitude.roll),
                    userAcceleration: Acceleration(x: accel.x, y: accel.y, z: accel.z),
                    buttonA: false
                )
            )
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
#endif
