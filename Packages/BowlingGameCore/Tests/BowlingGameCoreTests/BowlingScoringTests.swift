import Foundation
import Testing
@testable import BowlingGameCore

struct BowlingScoringTests {
    @Test func perfectGameIs300() {
        let rolls = Array(repeating: 10, count: 12)
        #expect(BowlingScoring.isComplete(rolls: rolls))
        #expect(BowlingScoring.totalScore(rolls: rolls) == 300)
    }

    @Test func allSparesWithFiveFillIs150() {
        var rolls: [Int] = []
        for _ in 1...10 {
            rolls.append(contentsOf: [5, 5])
        }
        rolls.append(5)
        #expect(BowlingScoring.totalScore(rolls: rolls) == 150)
    }

    @Test func gutterGameIsZero() {
        let rolls = Array(repeating: 0, count: 20)
        #expect(BowlingScoring.totalScore(rolls: rolls) == 0)
    }

    @Test func openFramesAccumulateImmediately() {
        let rolls = [9, 0, 8, 1]
        let frames = BowlingScoring.frames(from: rolls)
        #expect(frames[0].cumulativeScore == 9)
        #expect(frames[1].cumulativeScore == 18)
        #expect(BowlingScoring.isComplete(rolls: rolls) == false)
    }

    @Test func strikeWaitsForTwoBonusRolls() {
        let frames = BowlingScoring.frames(from: [10, 7])
        #expect(frames[0].isStrike)
        #expect(frames[0].cumulativeScore == nil)
        let resolved = BowlingScoring.frames(from: [10, 7, 2])
        #expect(resolved[0].cumulativeScore == 19)
    }

    @Test func kataExample() {
        let rolls = [10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1]
        #expect(BowlingScoring.isComplete(rolls: rolls))
        #expect(BowlingScoring.totalScore(rolls: rolls) == 167)
    }
}
