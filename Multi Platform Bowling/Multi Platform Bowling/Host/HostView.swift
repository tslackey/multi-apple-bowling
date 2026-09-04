#if os(macOS) || os(tvOS)
import SwiftUI
import RealityKit
import Combine
import BowlingGameCore

struct HostView: View {
    @State private var session = HostSession()
    @State private var lane = LaneScene()
    @State private var throwStartedAt: Date?
    @State private var settleResetTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LaneView(scene: lane)
            VStack {
                header
                Spacer()
                controls
            }
            .padding(24)
        }
        .background(Color.black)
        .task {
            await lane.build()
            session.onThrow = { commit in
                throwStartedAt = Date()
                lane.apply(commit)
            }
            session.onResetLane = {
                throwStartedAt = nil
                lane.reset()
            }
            session.start()
        }
        .onDisappear {
            session.stop()
            settleResetTask?.cancel()
        }
        .onReceive(Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()) { _ in
            tick()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.overlayTitle)
                    .font(.largeTitle.bold())
                Text(session.statusText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(session.pinsStanding) standing")
                    .font(.title.monospacedDigit().bold())
                if let connectedName = session.connectedName {
                    Text(connectedName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        HStack {
            Button("Reset Lane") {
                settleResetTask?.cancel()
                session.resetLane()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
    }

    private func tick() {
        guard session.phase == .ballInPlay else { return }
        let elapsed = Date().timeIntervalSince(throwStartedAt ?? .now)
        let timedOut = elapsed > 8
        let minTime = elapsed > 1.3
        if timedOut || lane.isSettled(minimumTimeElapsed: minTime) {
            session.handleSettledPins(standing: lane.standingPinCount())
            settleResetTask?.cancel()
            settleResetTask = Task {
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { return }
                session.returnToAiming()
            }
        }
    }
}

struct LaneView: View {
    var scene: LaneScene

    var body: some View {
        RealityView { content in
            content.add(scene.root)
        }
    }
}
#endif
