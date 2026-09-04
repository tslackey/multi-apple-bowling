import Foundation

/// Standard 10-pin scoring. Incomplete games only report frames whose bonus window is filled.
public enum BowlingScoring: Sendable {
    public static let frameCount = 10
    public static let pinsPerFrame = 10

    public static func isComplete(rolls: [Int]) -> Bool {
        guard let tenth = startIndex(ofFrame: frameCount, rolls: rolls) else { return false }
        guard tenth < rolls.count else { return false }
        let first = rolls[tenth]
        if first == 10 {
            return rolls.count >= tenth + 3
        }
        guard rolls.count >= tenth + 2 else { return false }
        if first + rolls[tenth + 1] == 10 {
            return rolls.count >= tenth + 3
        }
        return true
    }

    public static func totalScore(rolls: [Int]) -> Int? {
        frames(from: rolls).reversed().first(where: { $0.cumulativeScore != nil })?.cumulativeScore
    }

    public static func frames(from rolls: [Int]) -> [Frame] {
        var result: [Frame] = []
        var index = 0
        var cumulative = 0

        for frameNumber in 1...frameCount {
            if frameNumber < frameCount {
                guard index < rolls.count else {
                    result.append(Frame(id: frameNumber))
                    continue
                }

                if rolls[index] == 10 {
                    let bonus = sum(rolls, from: index + 1, count: 2)
                    if let bonus {
                        cumulative += 10 + bonus
                    }
                    result.append(
                        Frame(
                            id: frameNumber,
                            rolls: [10],
                            cumulativeScore: bonus == nil ? nil : cumulative
                        )
                    )
                    index += 1
                } else if index + 1 < rolls.count {
                    let first = rolls[index]
                    let second = rolls[index + 1]
                    if first + second == 10 {
                        let bonus = sum(rolls, from: index + 2, count: 1)
                        if let bonus {
                            cumulative += 10 + bonus
                        }
                        result.append(
                            Frame(
                                id: frameNumber,
                                rolls: [first, second],
                                cumulativeScore: bonus == nil ? nil : cumulative
                            )
                        )
                    } else {
                        cumulative += first + second
                        result.append(
                            Frame(
                                id: frameNumber,
                                rolls: [first, second],
                                cumulativeScore: cumulative
                            )
                        )
                    }
                    index += 2
                } else {
                    result.append(Frame(id: frameNumber, rolls: [rolls[index]]))
                    index += 1
                }
            } else {
                let remaining = index < rolls.count ? Array(rolls[index...]) : []
                let tenth: Int?
                if remaining.first == 10 {
                    tenth = remaining.count >= 3 ? remaining.prefix(3).reduce(0, +) : nil
                } else if remaining.count >= 2, remaining[0] + remaining[1] == 10 {
                    tenth = remaining.count >= 3 ? remaining.prefix(3).reduce(0, +) : nil
                } else if remaining.count >= 2 {
                    tenth = remaining[0] + remaining[1]
                } else {
                    tenth = nil
                }
                if let tenth {
                    cumulative += tenth
                }
                result.append(
                    Frame(
                        id: frameNumber,
                        rolls: remaining,
                        cumulativeScore: tenth == nil ? nil : cumulative
                    )
                )
            }
        }

        return result
    }

    private static func startIndex(ofFrame frame: Int, rolls: [Int]) -> Int? {
        var index = 0
        for current in 1..<frame {
            guard index < rolls.count else { return nil }
            if rolls[index] == 10 {
                index += 1
            } else {
                guard index + 1 < rolls.count else { return nil }
                index += 2
            }
            _ = current
        }
        return index
    }

    private static func sum(_ rolls: [Int], from start: Int, count: Int) -> Int? {
        guard start >= 0, start + count <= rolls.count else { return nil }
        return rolls[start..<(start + count)].reduce(0, +)
    }
}
