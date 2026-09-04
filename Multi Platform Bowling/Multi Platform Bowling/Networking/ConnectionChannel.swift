import Foundation
import Network
import BowlingGameCore

enum BowlingNetwork {
    static func parameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true
        return parameters
    }
}

@MainActor
final class ConnectionChannel {
    let connection: NWConnection
    var onMessage: ((NetworkMessage) -> Void)?
    var onReady: (() -> Void)?
    var onFailed: ((String) -> Void)?

    private var assembler = MessageAssembler()
    private var isReceiving = false
    private var isStopping = false
    private var didFinish = false
    private var didBecomeReady = false

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handle(state)
            }
        }
        connection.start(queue: .main)
    }

    func send(_ message: NetworkMessage) {
        guard !isStopping else { return }
        do {
            let data = try MessageAssembler.frame(message)
            connection.send(content: data, completion: .contentProcessed { _ in })
        } catch {
            fail(error.localizedDescription)
        }
    }

    func cancel() {
        isStopping = true
        onMessage = nil
        onReady = nil
        onFailed = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            guard !didBecomeReady else { return }
            didBecomeReady = true
            receive()
            onReady?()
        case .failed(let error):
            fail(error.localizedDescription)
        case .cancelled:
            fail("Disconnected")
        default:
            break
        }
    }

    private func fail(_ message: String) {
        guard !didFinish, !isStopping else { return }
        didFinish = true
        onFailed?(message)
    }

    private func receive() {
        guard !isReceiving, !didFinish, !isStopping else { return }
        isReceiving = true
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self, !self.isStopping else { return }
                self.isReceiving = false
                if let data, !data.isEmpty {
                    do {
                        for message in try self.assembler.append(data) {
                            self.onMessage?(message)
                        }
                    } catch {
                        self.fail(error.localizedDescription)
                        return
                    }
                }
                if let error {
                    self.fail(error.localizedDescription)
                    return
                }
                if isComplete {
                    self.fail("Disconnected")
                    return
                }
                self.receive()
            }
        }
    }
}
