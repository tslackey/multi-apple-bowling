#if os(iOS)
import SwiftUI
import BowlingGameCore

struct ControllerView: View {
    @State private var session = ControllerSession()
    @State private var motion = MotionSource()
    @State private var detector = ThrowDetector(playerID: UUID())
    @State private var debugPower = 0.7
    @State private var debugHook = 0.0
    @State private var lastThrowStatus = "Swing like a Wii Remote, or use a debug throw."

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                statusCard
                if session.isConnected {
                    playCard
                    debugCard
                } else {
                    hostList
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Bowling Remote")
        }
        .preferredColorScheme(.dark)
        .onAppear {
            detector.playerID = session.playerID
            session.startBrowsing()
            motion.onSample = handleMotion
            motion.start()
        }
        .onDisappear {
            motion.stop()
            session.disconnect()
            session.stopBrowsing()
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.statusText)
                .font(.headline)
            if let snapshot = session.snapshot {
                Text(phaseCopy(snapshot.state.phase))
                    .font(.title2.bold())
                Text("\(snapshot.state.pinsStanding) pins standing")
                    .foregroundStyle(.secondary)
            } else if !motion.isAvailable {
                Text("Simulator has no gyro — use Debug Throw.")
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
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
                List(session.hosts) { host in
                    Button(host.name) {
                        session.join(host)
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 180)
            }
        }
    }

    private var playCard: some View {
        VStack(spacing: 12) {
            Text(lastThrowStatus)
                .multilineTextAlignment(.center)
            Button("Release (Button A)") {
                sendManualRelease()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Disconnect", role: .destructive, action: session.disconnect)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var debugCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Throw")
                .font(.headline)
            Text("For Simulator, or to skip the swing.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("Power") {
                Slider(value: $debugPower, in: 0...1)
            }
            LabeledContent("Hook") {
                Slider(value: $debugHook, in: -1...1)
            }
            Button("Throw") {
                send(
                    ThrowMapper.debug(
                        playerID: session.playerID,
                        power: debugPower,
                        hook: debugHook,
                        timestamp: ProcessInfo.processInfo.systemUptime
                    )
                )
                lastThrowStatus = "Debug throw sent"
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func handleMotion(_ input: ControllerInput) {
        session.send(.controllerInput(input))
        if session.snapshot?.state.phase == .aiming, let commit = detector.ingest(input) {
            send(commit)
            lastThrowStatus = "Swing sent"
        }
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
            lastThrowStatus = "Button A throw sent"
        } else {
            send(
                ThrowMapper.debug(
                    playerID: session.playerID,
                    power: debugPower,
                    hook: debugHook,
                    timestamp: input.timestamp
                )
            )
            lastThrowStatus = "Button A debug throw sent"
        }
        input.buttonA = false
        _ = detector.ingest(input)
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
