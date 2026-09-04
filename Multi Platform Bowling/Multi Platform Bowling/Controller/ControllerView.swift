#if os(iOS)
import SwiftUI
import UIKit
import BowlingGameCore

struct ControllerView: View {
    @State private var session = ControllerSession()
    @State private var motion = MotionSource()
    @State private var detector = ThrowDetector(playerID: UUID())
    @State private var anchorSession = LaneAnchorSession()
    @State private var throwMode: ThrowReleaseMode = .automatic
    @State private var debugPower = 0.7
    @State private var debugHook = 0.0
    @State private var lastThrowStatus = "Hold the phone upright and swing forward."
    @State private var showDebug = false
    @State private var showScanner = false
    @State private var holdPressed = false
    @State private var lastMotion: ControllerInput?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusCard
                    if session.isJoining {
                        connectingCard
                    } else if session.isConnected {
                        throwCard
                        debugCard
                    } else {
                        scanButton
                        hostList
                    }
                }
                .padding()
            }
            .navigationTitle("Bowling Remote")
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView(session: anchorSession) {
                showScanner = false
                anchorSession.stopScanning()
            }
        }
        .onAppear {
            detector.playerID = session.playerID
            session.startBrowsing()
            motion.onSample = handleMotion
            anchorSession.onCode = handleScannedCode
        }
        .onDisappear {
            motion.stop()
            session.disconnect()
            session.stopBrowsing()
            anchorSession.stop()
        }
        .onChange(of: session.isConnected) { _, connected in
            if connected {
                detector.reset()
                lastThrowStatus = throwMode == .holdToThrow
                    ? "Press and hold, swing, then release."
                    : "Hold the phone upright and swing forward."
                motion.start()
            } else {
                motion.stop()
                detector.reset()
                if !showScanner {
                    anchorSession.stop()
                }
            }
        }
        .onChange(of: throwMode) { _, mode in
            detector.releaseMode = mode
            detector.reset()
            holdPressed = false
            lastThrowStatus = mode == .holdToThrow
                ? "Press and hold, swing, then release."
                : "Hold the phone upright and swing forward."
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.statusText)
                .font(.headline)
            if let snapshot = session.snapshot {
                Text(phaseCopy(snapshot.state.phase))
                    .font(.title2.bold())
                Text("\(snapshot.state.pinsStanding) pins standing")
                    .foregroundStyle(.secondary)
            } else if session.isConnected {
                Text("Connected — waiting for the lane…")
                    .foregroundStyle(.secondary)
            } else if let motionError = motion.motionError {
                Text(motionError)
                    .foregroundStyle(.orange)
            } else if !motion.isAvailable {
                Text("No gyro on this device — use Throw now.")
                    .foregroundStyle(.orange)
            }
            if session.isConnected {
                Text(anchorSession.isLocked
                     ? "Aim locked to the host screen"
                     : "Scan the host QR to lock 3D aim")
                    .font(.subheadline)
                    .foregroundStyle(anchorSession.isLocked ? .green : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var connectingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to \(session.selectedHostName ?? "host")")
                .font(.title3.bold())
            Text("Leave this screen open. The Mac should show that your iPhone joined.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Cancel", role: .cancel, action: session.disconnect)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            Label("Scan host QR", systemImage: "qrcode.viewfinder")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var hostList: some View {
        Group {
            if session.hosts.isEmpty {
                ContentUnavailableView(
                    "No games nearby",
                    systemImage: "wifi",
                    description: Text("Scan the QR on the Mac or Apple TV, or start a host on this Wi-Fi.")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(session.hosts) { host in
                        Button {
                            session.join(host)
                        } label: {
                            HStack {
                                Text(host.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 14)
                        }
                        if host.id != session.hosts.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var throwCard: some View {
        VStack(spacing: 16) {
            Text(aimingCopy)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(throwMode == .holdToThrow
                 ? "Portrait, screen toward you, top aimed at the pins. Hold, swing, release."
                 : "Portrait, screen toward you, top of the phone aimed at the pins. Swing like a Wii Remote.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Picker("Throw mode", selection: $throwMode) {
                Text("Swing").tag(ThrowReleaseMode.automatic)
                Text("Hold & release").tag(ThrowReleaseMode.holdToThrow)
            }
            .pickerStyle(.segmented)

            swingMeter
            aimMeter

            Text(lastThrowStatus)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if throwMode == .holdToThrow {
                holdToThrowPad
            } else {
                Button("Throw now") {
                    sendManualRelease()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canThrow)
            }

            Button {
                showScanner = true
            } label: {
                Label(
                    anchorSession.isLocked ? "Rescan aim QR" : "Scan QR to lock aim",
                    systemImage: "qrcode.viewfinder"
                )
            }
            .buttonStyle(.bordered)

            Button("Disconnect", role: .destructive, action: session.disconnect)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var holdToThrowPad: some View {
        Text(holdPressed ? "Release to throw" : "Hold • Swing • Release")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(holdPressed ? Color.green.opacity(0.85) : Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(canThrow ? 1 : 0.45)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard canThrow, !holdPressed else { return }
                        setHoldPressed(true)
                    }
                    .onEnded { _ in
                        setHoldPressed(false)
                    }
            )
            .disabled(!canThrow)
            .accessibilityAddTraits(.isButton)
    }

    private var swingMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(motion.isRunning ? "Swing strength" : "Motion off")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))
                    Capsule()
                        .fill(meterColor)
                        .frame(width: max(8, geo.size.width * motion.swingLevel))
                }
            }
            .frame(height: 14)
        }
    }

    private var aimMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(anchorSession.isLocked ? "Aim vs screen" : "Aim (gyro only)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                let heading = anchorSession.currentAim?.heading ?? 0
                let x = geo.size.width / 2
                    + CGFloat(heading / ThrowMapper.maxHeading) * (geo.size.width / 2 - 8)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))
                    Rectangle()
                        .fill(.white.opacity(0.35))
                        .frame(width: 2, height: 14)
                        .offset(x: geo.size.width / 2 - 1)
                    Circle()
                        .fill(anchorSession.isLocked ? Color.green : Color.accentColor)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, min(geo.size.width - 14, x - 7)))
                }
            }
            .frame(height: 14)
        }
    }

    private var debugCard: some View {
        DisclosureGroup("Debug throw", isExpanded: $showDebug) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Skips the swing. Useful if motion looks dead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Power") {
                    Slider(value: $debugPower, in: 0...1)
                }
                LabeledContent("Hook") {
                    Slider(value: $debugHook, in: -1...1)
                }
                Button("Send debug throw") {
                    sendDebugThrow()
                }
                .buttonStyle(.bordered)
                .disabled(!canThrow)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var canThrow: Bool {
        switch session.snapshot?.state.phase {
        case .none, .aiming, .lobby:
            return true
        default:
            return false
        }
    }

    private var aimingCopy: String {
        switch session.snapshot?.state.phase {
        case .ballInPlay:
            return "Ball is rolling on the Mac"
        case .frameOver:
            return "Pins are down — hang on"
        case .gameOver:
            return "Game over"
        default:
            return "Your throw"
        }
    }

    private var meterColor: Color {
        motion.swingLevel > 0.55 ? .green : .accentColor
    }

    private func handleScannedCode(_ code: HostJoinCode) {
        showScanner = false
        if !session.isConnected, !session.isJoining {
            session.join(code: code)
        }
    }

    private func handleMotion(_ input: ControllerInput) {
        guard session.isConnected else { return }
        var sample = input
        sample.buttonA = throwMode == .holdToThrow && holdPressed
        lastMotion = sample
        anchorSession.latestYaw = sample.attitude.yaw
        guard canThrow, let commit = detector.ingest(sample, aim: currentAim) else { return }
        send(commit)
        lastThrowStatus = "Swing sent — watch the Mac"
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func setHoldPressed(_ pressed: Bool) {
        guard throwMode == .holdToThrow else { return }
        if pressed {
            holdPressed = true
            lastThrowStatus = "Holding — swing, then release"
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        holdPressed = false
        var sample = lastMotion ?? ControllerInput(
            timestamp: ProcessInfo.processInfo.systemUptime,
            attitude: .zero,
            userAcceleration: .zero,
            buttonA: false
        )
        sample.buttonA = false
        sample.timestamp = ProcessInfo.processInfo.systemUptime
        if canThrow, let commit = detector.ingest(sample, aim: currentAim) {
            send(commit)
            lastThrowStatus = "Throw sent — watch the Mac"
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    private var currentAim: LaneAim? {
        anchorSession.currentAim
    }

    private func sendManualRelease() {
        var input = ControllerInput(
            timestamp: ProcessInfo.processInfo.systemUptime,
            attitude: lastMotion?.attitude ?? .zero,
            userAcceleration: Acceleration(x: 0, y: 2.2, z: 0),
            buttonA: true
        )
        if let commit = detector.ingest(input, aim: currentAim) {
            send(commit)
            lastThrowStatus = "Throw sent — watch the Mac"
        } else {
            sendDebugThrow()
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        input.buttonA = false
        _ = detector.ingest(input, aim: currentAim)
    }

    private func sendDebugThrow() {
        send(
            ThrowMapper.debug(
                playerID: session.playerID,
                power: debugPower,
                hook: debugHook,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
        )
        lastThrowStatus = "Debug throw sent — watch the Mac"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func send(_ commit: ThrowCommit) {
        session.send(.throwCommit(commit))
    }

    private func phaseCopy(_ phase: GamePhase) -> String {
        switch phase {
        case .lobby: "Waiting for host"
        case .aiming: "Your throw"
        case .ballInPlay: "Ball in play"
        case .frameOver: "Pins down"
        case .gameOver: "Game over"
        }
    }
}
#endif
