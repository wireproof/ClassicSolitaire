import XCTest
@testable import SolitaireEngine
final class GameTests: XCTestCase {
    func testDealHasEveryCardAndCorrectFaceUpCards() {
        let game = Game(shuffled: false)
        XCTAssertEqual(game.stock.count, 24)
        XCTAssertEqual(game.tableau.map(\.count), [1,2,3,4,5,6,7])
        XCTAssertTrue(game.tableau.allSatisfy { $0.last!.faceUp && $0.dropLast().allSatisfy { !$0.faceUp } })
        XCTAssertEqual(Set((game.stock + game.tableau.flatMap { $0 }).map(\.id)).count, 52)
    }
    func testDrawThreeAndRecyclePreservesOrder() {
        var game = Game(drawCount: 3, shuffled: false)
        let original = game.stock
        while !game.stock.isEmpty { game.draw() }
        XCTAssertEqual(game.waste.count, 24)
        game.draw()
        XCTAssertEqual(game.stock, original)
        XCTAssertTrue(game.waste.isEmpty)
    }
    func testMovesAndReveal() {
        var game = Game(shuffled: false)
        game.tableau = Array(repeating: [], count: 7)
        game.tableau[0] = [Card(suit: .clubs, rank: 2), Card(suit: .hearts, rank: 7, faceUp: true), Card(suit: .clubs, rank: 6, faceUp: true)]
        game.tableau[1] = [Card(suit: .spades, rank: 8, faceUp: true)]
        XCTAssertFalse(game.move(from: .tableau(0), index: 1, to: .foundation(0)))
        XCTAssertTrue(game.move(from: .tableau(0), index: 1, to: .tableau(1)))
        XCTAssertTrue(game.tableau[0][0].faceUp)
        XCTAssertEqual(game.tableau[1].count, 3)
        XCTAssertFalse(game.move(from: .tableau(1), index: 2, to: .tableau(2)))
        game.waste = [Card(suit: .hearts, rank: 1, faceUp: true)]
        XCTAssertTrue(game.moveToFoundation(from: .waste, index: 0))
    }
    func testSavedGameRoundTripAndRejectsInvalidDeck() throws {
        var game = Game(drawCount: 3, shuffled: false)
        game.draw()
        let restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(restored.stock, game.stock)
        XCTAssertEqual(restored.waste, game.waste)
        game.waste.append(game.stock[0])
        XCTAssertFalse(game.isValid)
        game.tableau.removeLast()
        XCTAssertFalse(game.isValid)
    }
}
