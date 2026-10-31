import Foundation

public enum Suit: String, Codable, CaseIterable { case clubs, diamonds, hearts, spades
    public var symbol: String { switch self { case .clubs: return "♣"; case .diamonds: return "♦"; case .hearts: return "♥"; case .spades: return "♠" } }
    public var isRed: Bool { self == .diamonds || self == .hearts }
}
public struct Card: Codable, Equatable, Identifiable, Hashable {
    public let suit: Suit
    public let rank: Int
    public var faceUp: Bool
    public var id: String { "\(suit.rawValue)-\(rank)" }
    public var label: String { ([1:"A", 11:"J", 12:"Q", 13:"K"][rank] ?? String(rank)) + suit.symbol }
    public init(suit: Suit, rank: Int, faceUp: Bool = false) { self.suit = suit; self.rank = rank; self.faceUp = faceUp }
}
public enum Pile: Equatable { case waste, foundation(Int), tableau(Int) }
public struct Game: Codable {
    public var stock: [Card] = []
    public var waste: [Card] = []
    public var foundations: [[Card]] = Array(repeating: [], count: 4)
    public var tableau: [[Card]] = Array(repeating: [], count: 7)
    public var drawCount: Int
    public init(drawCount: Int = 1, shuffled: Bool = true) {
        self.drawCount = drawCount == 3 ? 3 : 1
        var deck = Suit.allCases.flatMap { suit in (1...13).map { Card(suit: suit, rank: $0) } }
        if shuffled { deck.shuffle() }
        for column in 0..<7 { for row in 0...column { var card = deck.removeLast(); card.faceUp = row == column; tableau[column].append(card) } }
        stock = deck
    }
    public var isValid: Bool {
        guard foundations.count == 4, tableau.count == 7, drawCount == 1 || drawCount == 3 else { return false }
        let all = stock + waste + foundations.flatMap { $0 } + tableau.flatMap { $0 }
        return all.count == 52 && Set(all.map(\.id)).count == 52 && all.allSatisfy { (1...13).contains($0.rank) }
    }
    public var won: Bool { foundations.allSatisfy { $0.count == 13 } }
    public mutating func draw() {
        if stock.isEmpty { stock = waste.reversed().map { var c = $0; c.faceUp = false; return c }; waste.removeAll(); return }
        for _ in 0..<drawCount where !stock.isEmpty { var c = stock.removeLast(); c.faceUp = true; waste.append(c) }
    }
    public func cards(in pile: Pile) -> [Card] { switch pile { case .waste: return waste; case .foundation(let i): return foundations.indices.contains(i) ? foundations[i] : []; case .tableau(let i): return tableau.indices.contains(i) ? tableau[i] : [] } }
    @discardableResult public mutating func move(from: Pile, index: Int, to: Pile) -> Bool {
        guard from != to else { return false }
        let source = cards(in: from), destination = cards(in: to)
        guard source.indices.contains(index), source[index].faceUp else { return false }
        switch from { case .waste, .foundation: guard index == source.count - 1 else { return false }; case .tableau: break }
        let moving = Array(source[index...]); let card = moving[0]
        guard moving.allSatisfy(\.faceUp) else { return false }
        if moving.count > 1 { for i in 1..<moving.count { guard moving[i-1].rank == moving[i].rank + 1 && moving[i-1].suit.isRed != moving[i].suit.isRed else { return false } } }
        switch to {
        case .waste: return false
        case .foundation(let i):
            guard foundations.indices.contains(i), moving.count == 1 else { return false }
            if let top = destination.last { guard top.suit == card.suit && card.rank == top.rank + 1 else { return false } }
            else { guard card.rank == 1 else { return false } }
        case .tableau(let i):
            guard tableau.indices.contains(i) else { return false }
            if let top = destination.last { guard top.faceUp && top.rank == card.rank + 1 && top.suit.isRed != card.suit.isRed else { return false } }
            else { guard card.rank == 13 else { return false } }
        }
        switch from { case .waste: waste.removeSubrange(index...); case .foundation(let i): foundations[i].removeSubrange(index...); case .tableau(let i): tableau[i].removeSubrange(index...); if !tableau[i].isEmpty { tableau[i][tableau[i].count - 1].faceUp = true } }
        switch to { case .waste: break; case .foundation(let i): foundations[i].append(contentsOf: moving); case .tableau(let i): tableau[i].append(contentsOf: moving) }
        return true
    }
    @discardableResult public mutating func moveToFoundation(from: Pile, index: Int) -> Bool { for i in 0..<4 { if move(from: from, index: index, to: .foundation(i)) { return true } }; return false }
}
