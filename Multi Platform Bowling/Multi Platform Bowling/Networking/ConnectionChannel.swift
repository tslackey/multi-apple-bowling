import Foundation
import Network
import BowlingGameCore

enum BowlingNetwork {
    static let parameters: NWParameters = {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true
        return parameters
    }()
}

@MainActor
final class ConnectionChannel {
    let connection: NWConnection
    var onMessage: ((NetworkMessage) -> Void)?
    var onReady: (() -> Void)?
    var onFailed: ((String) -> Void)?

    private var assembler = MessageAssembler()
    private var isReceiving = false

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
        receive()
    }

    func send(_ message: NetworkMessage) {
        do {
            let data = try MessageAssembler.frame(message)
            connection.send(content: data, completion: .contentProcessed { _ in })
        } catch {
            onFailed?(error.localizedDescription)
        }
    }

    func cancel() {
        connection.cancel()
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            onReady?()
        case .failed(let error):
            onFailed?(error.localizedDescription)
        case .cancelled:
            onFailed?("Disconnected")
        default:
            break
        }
    }

    private func receive() {
        guard !isReceiving else { return }
        isReceiving = true
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                self.isReceiving = false
                if let data, !data.isEmpty {
                    do {
                        for message in try self.assembler.append(data) {
                            self.onMessage?(message)
                        }
                    } catch {
                        self.onFailed?(error.localizedDescription)
                        return
                    }
                }
                if let error {
                    self.onFailed?(error.localizedDescription)
                    return
                }
                if isComplete {
                    self.onFailed?("Disconnected")
                    return
                }
                self.receive()
            }
        }
    }
}
