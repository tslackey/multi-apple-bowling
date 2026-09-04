#if os(iOS)
import Foundation
import Network
import Observation
import BowlingGameCore

struct DiscoveredHost: Identifiable, Hashable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

@Observable
@MainActor
final class ControllerSession {
    var hosts: [DiscoveredHost] = []
    var statusText = "Looking for a game…"
    var snapshot: GameSnapshot?
    var isConnected = false
    var selectedHostName: String?

    let playerID = UUID()

    private var browser: NWBrowser?
    private var channel: ConnectionChannel?

    func startBrowsing() {
        stopBrowsing()
        let browser = NWBrowser(for: .bonjour(type: BonjourService.type, domain: nil), using: BowlingNetwork.parameters)
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed(let error) = state {
                    self?.statusText = error.localizedDescription
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.hosts = results.compactMap { result in
                    guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                    return DiscoveredHost(
                        id: result.endpoint.debugDescription,
                        name: name,
                        endpoint: result.endpoint
                    )
                }
                .sorted { $0.name < $1.name }
                if self?.isConnected != true {
                    self?.statusText = self?.hosts.isEmpty == true
                        ? "Looking for a Mac or Apple TV…"
                        : "Select a game"
                }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    func join(_ host: DiscoveredHost) {
        channel?.cancel()
        selectedHostName = host.name
        statusText = "Joining \(host.name)…"
        let connection = NWConnection(to: host.endpoint, using: BowlingNetwork.parameters)
        let next = ConnectionChannel(connection: connection)
        next.onReady = { [weak self] in
            guard let self else { return }
            self.isConnected = true
            self.statusText = "Connected to \(host.name)"
            self.stopBrowsing()
            next.send(
                .join(
                    JoinMessage(playerID: self.playerID, displayName: PlatformIdentity.controllerDisplayName)
                )
            )
        }
        next.onFailed = { [weak self] message in
            self?.handleDisconnect(message)
        }
        next.onMessage = { [weak self] message in
            if case .snapshot(let snapshot) = message {
                self?.snapshot = snapshot
            }
        }
        channel = next
        next.start()
    }

    func send(_ message: NetworkMessage) {
        channel?.send(message)
    }

    func disconnect() {
        channel?.cancel()
        handleDisconnect("Disconnected")
    }

    private func handleDisconnect(_ message: String) {
        isConnected = false
        snapshot = nil
        selectedHostName = nil
        channel = nil
        statusText = message
        startBrowsing()
    }
}
#endif
