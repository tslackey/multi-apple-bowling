#if os(iOS)
import SwiftUI
import UIKit
import BowlingGameCore

struct ControllerView: View {
    @State private var session = ControllerSession()
    @State private var motion = MotionSource()
    @State private var detector = ThrowDetector(playerID: UUID())
    @State private var debugPower = 0.7
    @State private var debugHook = 0.0
    @State private var lastThrowStatus = "Hold the phone upright and swing forward."
    @State private var showDebug = false

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
                        hostList
                    }
                }
                .padding()
            }
            .navigationTitle("Bowling Remote")
        }
        .preferredColorScheme(.dark)
        .onAppear {
            detector.playerID = session.playerID
            session.startBrowsing()
            motion.onSample = handleMotion
        }
        .onDisappear {
            motion.stop()
            session.disconnect()
            session.stopBrowsing()
        }
        .onChange(of: session.isConnected) { _, connected in
            if connected {
                detector.reset()
                lastThrowStatus = "Hold the phone upright and swing forward."
                motion.start()
            } else {
                motion.stop()
                detector.reset()
            }
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

    private var hostList: some View {
        Group {
            if session.hosts.isEmpty {
                ContentUnavailableView(
                    "No games nearby",
                    systemImage: "wifi",
                    description: Text("Start the host on a Mac or Apple TV on this Wi-Fi.")
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
            Text("Portrait, screen toward you, top of the phone aimed at the pins. Swing like a Wii Remote.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            swingMeter

            Text(lastThrowStatus)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Throw now") {
                sendManualRelease()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canThrow)

            Button("Disconnect", role: .destructive, action: session.disconnect)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

    private func handleMotion(_ input: ControllerInput) {
        guard session.isConnected else { return }
        guard canThrow, let commit = detector.ingest(input) else { return }
        send(commit)
        lastThrowStatus = "Swing sent — watch the Mac"
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func sendManualRelease() {
        var input = ControllerInput(
            timestamp: ProcessInfo.processInfo.systemUptime,
            attitude: .zero,
            userAcceleration: Acceleration(x: 0, y: 2.2, z: 0),
            buttonA: true
        )
        if let commit = detector.ingest(input) {
            send(commit)
            lastThrowStatus = "Throw sent — watch the Mac"
        } else {
            sendDebugThrow()
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        input.buttonA = false
        _ = detector.ingest(input)
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
