//
//  CardGroup.swift
//  Yeetcard
//

import Foundation
import SwiftData

@Model
final class CardGroup {
    var id: UUID
    var name: String
    var dateCreated: Date

    @Relationship(deleteRule: .nullify, inverse: \Card.group)
    var cards: [Card]

    var sortedCards: [Card] {
        cards.sorted { $0.dateAdded < $1.dateAdded }
    }

    var primaryCard: Card? {
        sortedCards.first
    }

    var cardCount: Int {
        cards.count
    }

    init(
        id: UUID = UUID(),
        name: String,
        dateCreated: Date = Date(),
        cards: [Card] = []
    ) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
        self.cards = cards
    }
}
