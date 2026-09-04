#if os(iOS)
import ARKit
import AVFoundation
import Foundation
import Observation
import os
import RealityKit
import simd
import Vision
import BowlingGameCore

@Observable
@MainActor
final class LaneAnchorSession: NSObject, ARSessionDelegate {
    var isLocked = false
    var isRunning = false
    var statusText = "Point the camera at the QR on the Mac or Apple TV"
    var errorText: String?
    var currentAim: LaneAim?
    var latestYaw: Double = 0
    var onCode: ((HostJoinCode) -> Void)?

    let session = ARSession()
    let isSupported = ARWorldTrackingConfiguration.isSupported

    private var lockedPose: LaneAnchorPose?
    private var referenceYaw = 0.0
    private var isScanning = false
    private var worldAnchor: ARAnchor?
    private let visionQueue = DispatchQueue(label: "bowling.lane-anchor")
    nonisolated private let detection = OSAllocatedUnfairLock(initialState: DetectionControl())

    func beginScanning() {
        errorText = nil
        isLocked = false
        lockedPose = nil
        currentAim = nil
        isScanning = true
        detection.withLock { $0.shouldDetect = true }
        statusText = "Point the camera at the QR on the Mac or Apple TV"
        startSessionIfNeeded(resetTracking: true)
    }

    func stopScanning() {
        isScanning = false
        detection.withLock { $0.shouldDetect = false }
        if !isLocked {
            stop()
        }
    }

    func stop() {
        isScanning = false
        detection.withLock { $0.shouldDetect = false }
        isRunning = false
        isLocked = false
        lockedPose = nil
        currentAim = nil
        session.pause()
        if let worldAnchor {
            session.remove(anchor: worldAnchor)
            self.worldAnchor = nil
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let timestamp = frame.timestamp
        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )
        let imageWidth = Float(frame.camera.imageResolution.width)
        let focalLengthX = frame.camera.intrinsics.columns.0.x

        Task { @MainActor in
            self.updateAim(phonePosition: cameraPosition)
        }

        let shouldRunVision = detection.withLock { state -> Bool in
            guard state.shouldDetect, timestamp - state.lastVisionTime > 0.12 else { return false }
            state.lastVisionTime = timestamp
            return true
        }
        guard shouldRunVision else { return }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.capturedImage,
            orientation: .right,
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first,
              let payload = observation.payloadStringValue,
              let code = HostJoinCode.parse(payload)
        else {
            return
        }

        let distance = LaneAimSolver.estimatedDistance(
            qrNormalizedWidth: Float(observation.boundingBox.width),
            imageWidth: imageWidth,
            focalLengthX: focalLengthX
        )
        let pose = LaneAimSolver.poseFacingCamera(
            cameraPosition: cameraPosition,
            cameraForward: cameraForward,
            distance: distance
        )
        Task { @MainActor in
            self.handleLock(code: code, pose: pose)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.errorText = message
        }
    }

    private func startSessionIfNeeded(resetTracking: Bool) {
        guard isSupported else {
            errorText = "AR is not available here. Join from the nearby games list."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            runSession(resetTracking: resetTracking)
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    self.runSession(resetTracking: resetTracking)
                } else {
                    self.errorText = "Camera access is needed to scan the host QR."
                }
            }
        default:
            errorText = "Camera access is needed to scan the host QR. Enable it in Settings."
        }
    }

    private func runSession(resetTracking: Bool) {
        session.delegate = self
        session.delegateQueue = visionQueue
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        configuration.worldAlignment = .gravity
        var options: ARSession.RunOptions = []
        if resetTracking || !isRunning {
            options = [.resetTracking, .removeExistingAnchors]
        }
        session.run(configuration, options: options)
        isRunning = true
    }

    private func handleLock(code: HostJoinCode, pose: LaneAnchorPose) {
        guard isScanning else { return }
        lockedPose = pose
        referenceYaw = latestYaw
        isLocked = true
        isScanning = false
        detection.withLock { $0.shouldDetect = false }
        statusText = "Lane locked — step back and throw toward the screen"
        if let worldAnchor {
            session.remove(anchor: worldAnchor)
        }
        let anchor = ARAnchor(transform: makeTransform(pose))
        session.add(anchor: anchor)
        worldAnchor = anchor
        updateAim(phonePosition: pose.position + pose.towardBowler)
        onCode?(code)
    }

    private func updateAim(phonePosition: SIMD3<Float>) {
        guard let lockedPose else {
            currentAim = nil
            return
        }
        currentAim = LaneAimSolver.resolve(
            phonePosition: phonePosition,
            yawDelta: latestYaw - referenceYaw,
            anchor: lockedPose
        )
    }

    private func makeTransform(_ pose: LaneAnchorPose) -> simd_float4x4 {
        let x = pose.screenRight
        let z = pose.towardBowler
        let y = simd_normalize(simd_cross(z, x))
        return simd_float4x4(columns: (
            SIMD4(x.x, x.y, x.z, 0),
            SIMD4(y.x, y.y, y.z, 0),
            SIMD4(z.x, z.y, z.z, 0),
            SIMD4(pose.position.x, pose.position.y, pose.position.z, 1)
        ))
    }
}

private struct DetectionControl: Sendable {
    var shouldDetect = false
    var lastVisionTime: TimeInterval = 0

    nonisolated init() {
        shouldDetect = false
        lastVisionTime = 0
    }
}
#endif
