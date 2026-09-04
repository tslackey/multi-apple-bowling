import Foundation

public enum GamePhase: String, Codable, Sendable, Equatable {
    case lobby
    case aiming
    case ballInPlay
    case frameOver
    case gameOver
}

public struct Frame: Codable, Sendable, Equatable, Identifiable {
    public var id: Int
    public var rolls: [Int]
    public var cumulativeScore: Int?

    public init(id: Int, rolls: [Int] = [], cumulativeScore: Int? = nil) {
        self.id = id
        self.rolls = rolls
        self.cumulativeScore = cumulativeScore
    }

    public var isStrike: Bool { rolls.first == 10 }
    public var isSpare: Bool {
        rolls.count >= 2 && rolls[0] != 10 && rolls[0] + rolls[1] == 10
    }
}

public struct Player: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var displayName: String
    public var rolls: [Int]

    public init(id: UUID = UUID(), displayName: String, rolls: [Int] = []) {
        self.id = id
        self.displayName = displayName
        self.rolls = rolls
    }

    public var frames: [Frame] {
        BowlingScoring.frames(from: rolls)
    }

    public var totalScore: Int {
        BowlingScoring.totalScore(rolls: rolls) ?? 0
    }

    public var isGameComplete: Bool {
        BowlingScoring.isComplete(rolls: rolls)
    }
}

public struct GameState: Codable, Sendable, Equatable {
    public var phase: GamePhase
    public var players: [Player]
    public var currentPlayerIndex: Int
    public var pinsStanding: Int
    public var lastPinfall: Int?

    public init(
        phase: GamePhase = .lobby,
        players: [Player] = [],
        currentPlayerIndex: Int = 0,
        pinsStanding: Int = 10,
        lastPinfall: Int? = nil
    ) {
        self.phase = phase
        self.players = players
        self.currentPlayerIndex = currentPlayerIndex
        self.pinsStanding = pinsStanding
        self.lastPinfall = lastPinfall
    }

    public static let empty = GameState()

    public var currentPlayer: Player? {
        players.indices.contains(currentPlayerIndex) ? players[currentPlayerIndex] : nil
    }
}

public struct BowlingScore: Codable, Sendable, Equatable {
    public var rolls: [Int]

    public init(rolls: [Int] = []) {
        self.rolls = rolls
    }

    public var total: Int? { BowlingScoring.totalScore(rolls: rolls) }
    public var isComplete: Bool { BowlingScoring.isComplete(rolls: rolls) }
    public var frames: [Frame] { BowlingScoring.frames(from: rolls) }
}
