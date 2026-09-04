import Foundation

public struct JoinMessage: Codable, Sendable, Equatable {
    public var playerID: UUID
    public var displayName: String

    public init(playerID: UUID, displayName: String) {
        self.playerID = playerID
        self.displayName = displayName
    }
}

public struct HostAdvertisement: Codable, Sendable, Equatable {
    public var gameName: String
    public var playerCount: Int

    public init(gameName: String, playerCount: Int) {
        self.gameName = gameName
        self.playerCount = playerCount
    }
}

public struct GameSnapshot: Codable, Sendable, Equatable {
    public var state: GameState
    public var hostName: String

    public init(state: GameState, hostName: String) {
        self.state = state
        self.hostName = hostName
    }
}

public enum NetworkMessage: Codable, Sendable, Equatable {
    case join(JoinMessage)
    case throwCommit(ThrowCommit)
    case controllerInput(ControllerInput)
    case snapshot(GameSnapshot)
    case resetLane
}
