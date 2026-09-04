#if os(macOS) || os(tvOS)
import Foundation
import Network
import Observation
import BowlingGameCore

@Observable
@MainActor
final class HostSession {
    var statusText = "Starting host…"
    var pinsStanding = 10
    var lastPinfall: Int?
    var connectedName: String?
    var phase: GamePhase = .lobby

    var onThrow: ((ThrowCommit) -> Void)?
    var onResetLane: (() -> Void)?

    private var listener: NWListener?
    private var channel: ConnectionChannel?
    private var connectionGeneration = 0
    private var state = GameState()
    private let hostName = PlatformIdentity.hostDisplayName

    var overlayTitle: String {
        switch phase {
        case .lobby:
            return connectedName == nil ? "Waiting for iPhone…" : "Connected"
        case .aiming:
            return "Waiting for throw"
        case .ballInPlay:
            return "Ball in play"
        case .frameOver:
            if let lastPinfall {
                return lastPinfall == 10 ? "Strike!" : "\(lastPinfall) pin\(lastPinfall == 1 ? "" : "s") down"
            }
            return "Frame over"
        case .gameOver:
            return "Game over"
        }
    }

    func start() {
        state = GameState(phase: .lobby, pinsStanding: 10)
        phase = .lobby
        do {
            let listener = try NWListener(using: BowlingNetwork.parameters())
            listener.service = NWListener.Service(name: hostName, type: BonjourService.type)
            listener.stateUpdateHandler = { [weak self] listenerState in
                Task { @MainActor in
                    self?.handleListener(listenerState)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
            statusText = "Advertising as \(hostName)"
        } catch {
            statusText = "Could not start host: \(error.localizedDescription)"
        }
    }

    func stop() {
        connectionGeneration += 1
        channel?.cancel()
        channel = nil
        listener?.cancel()
        listener = nil
    }

    func resetLane() {
        lastPinfall = nil
        pinsStanding = 10
        state.pinsStanding = 10
        state.lastPinfall = nil
        state.phase = connectedName == nil ? .lobby : .aiming
        phase = state.phase
        onResetLane?()
        sendSnapshot()
    }

    func handleSettledPins(standing: Int) {
        let pinfall = max(0, 10 - standing)
        pinsStanding = standing
        lastPinfall = pinfall
        state.pinsStanding = standing
        state.lastPinfall = pinfall
        state.phase = .frameOver
        phase = .frameOver
        sendSnapshot()
    }

    func returnToAiming() {
        guard connectedName != nil else {
            state.phase = .lobby
            phase = .lobby
            sendSnapshot()
            return
        }
        pinsStanding = 10
        state.pinsStanding = 10
        state.phase = .aiming
        phase = .aiming
        onResetLane?()
        sendSnapshot()
    }

    private func handleListener(_ listenerState: NWListener.State) {
        switch listenerState {
        case .ready:
            statusText = "Waiting for iPhone on the local network…"
        case .failed(let error):
            statusText = "Listener failed: \(error.localizedDescription)"
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        connectionGeneration += 1
        let generation = connectionGeneration
        channel?.cancel()

        let next = ConnectionChannel(connection: connection)
        next.onReady = { [weak self] in
            guard let self, self.connectionGeneration == generation else { return }
            if self.connectedName == nil {
                self.statusText = "iPhone connected — waiting to join"
            }
        }
        next.onFailed = { [weak self] message in
            guard let self, self.connectionGeneration == generation else { return }
            self.dropConnection(message)
        }
        next.onMessage = { [weak self] message in
            guard let self, self.connectionGeneration == generation else { return }
            self.handle(message)
        }
        channel = next
        next.start()
    }

    private func handle(_ message: NetworkMessage) {
        switch message {
        case .join(let join):
            connectedName = join.displayName
            if state.players.isEmpty {
                state.players = [Player(id: join.playerID, displayName: join.displayName)]
            }
            state.phase = .aiming
            phase = .aiming
            statusText = "\(join.displayName) joined"
            sendSnapshot()
        case .throwCommit(let commit):
            guard phase == .aiming else { return }
            state.phase = .ballInPlay
            phase = .ballInPlay
            statusText = "Throw received"
            onThrow?(commit)
            sendSnapshot()
        case .controllerInput:
            break
        case .resetLane:
            resetLane()
        case .snapshot:
            break
        }
    }

    private func dropConnection(_ message: String) {
        connectionGeneration += 1
        channel?.cancel()
        channel = nil
        connectedName = nil
        state.players = []
        state.phase = .lobby
        phase = .lobby
        statusText = message
    }

    private func sendSnapshot() {
        let snapshot = GameSnapshot(state: state, hostName: hostName)
        channel?.send(.snapshot(snapshot))
    }
}
#endif
