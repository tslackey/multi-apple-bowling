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

    var isJoining: Bool {
        selectedHostName != nil && !isConnected
    }

    private var browser: NWBrowser?
    private var channel: ConnectionChannel?
    private var joinGeneration = 0
    private var joinRetryCount = 0
    private var joinQueue: [NWEndpoint] = []
    private var joinQueueIndex = 0

    func startBrowsing() {
        stopBrowsing()
        let browser = NWBrowser(for: .bonjour(type: BonjourService.type, domain: nil), using: BowlingNetwork.parameters())
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
                if self?.isConnected != true, self?.isJoining != true {
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
        joinQueue = [host.endpoint]
        joinQueueIndex = 0
        join(host, isRetry: false)
    }

    func join(code: HostJoinCode) {
        var endpoints: [NWEndpoint] = []
        if let port = NWEndpoint.Port(rawValue: code.port) {
            for address in code.addresses {
                endpoints.append(.hostPort(host: NWEndpoint.Host(address), port: port))
            }
        }
        endpoints.append(
            .service(name: code.serviceName, type: BonjourService.type, domain: "local.", interface: nil)
        )
        joinQueue = endpoints
        joinQueueIndex = 0
        join(
            DiscoveredHost(
                id: code.sessionID.uuidString,
                name: code.serviceName,
                endpoint: endpoints[0]
            ),
            isRetry: false
        )
    }

    func send(_ message: NetworkMessage) {
        channel?.send(message)
    }

    func disconnect() {
        joinGeneration += 1
        channel?.cancel()
        handleDisconnect("Disconnected")
    }

    private func join(_ host: DiscoveredHost, isRetry: Bool) {
        joinGeneration += 1
        let generation = joinGeneration
        if !isRetry {
            joinRetryCount = 0
        }

        channel?.cancel()
        channel = nil
        selectedHostName = host.name
        isConnected = false
        snapshot = nil
        statusText = isRetry ? "Retrying \(host.name)…" : "Joining \(host.name)…"

        let connection = NWConnection(to: host.endpoint, using: BowlingNetwork.parameters())
        let next = ConnectionChannel(connection: connection)
        next.onReady = { [weak self] in
            guard let self, self.joinGeneration == generation else { return }
            self.isConnected = true
            self.statusText = "Connected — hold like a Wii Remote"
            self.stopBrowsing()
            next.send(
                .join(
                    JoinMessage(playerID: self.playerID, displayName: PlatformIdentity.controllerDisplayName)
                )
            )
        }
        next.onFailed = { [weak self] message in
            guard let self, self.joinGeneration == generation else { return }
            if self.advanceJoinQueue(from: host) {
                return
            }
            self.handleDisconnect(message)
        }
        next.onMessage = { [weak self] message in
            guard let self, self.joinGeneration == generation else { return }
            if case .snapshot(let snapshot) = message {
                self.snapshot = snapshot
            }
        }
        channel = next
        next.start()
        scheduleJoinWatchdog(generation: generation, host: host)
    }

    private func scheduleJoinWatchdog(generation: Int, host: DiscoveredHost) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard joinGeneration == generation, !isConnected else { return }
            if advanceJoinQueue(from: host) {
                return
            }
            if joinRetryCount < 1 {
                joinRetryCount += 1
                join(host, isRetry: true)
                return
            }
            joinGeneration += 1
            channel?.cancel()
            channel = nil
            selectedHostName = nil
            statusText = "Could not connect to \(host.name). Tap it to try again."
            startBrowsing()
        }
    }

    private func advanceJoinQueue(from host: DiscoveredHost) -> Bool {
        guard joinQueueIndex + 1 < joinQueue.count else { return false }
        joinQueueIndex += 1
        join(
            DiscoveredHost(
                id: host.id,
                name: host.name,
                endpoint: joinQueue[joinQueueIndex]
            ),
            isRetry: true
        )
        return true
    }

    private func handleDisconnect(_ message: String) {
        joinGeneration += 1
        isConnected = false
        snapshot = nil
        selectedHostName = nil
        channel = nil
        statusText = message
        startBrowsing()
    }
}
#endif
