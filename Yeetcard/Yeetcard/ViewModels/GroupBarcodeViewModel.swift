//
//  GroupBarcodeViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class GroupBarcodeViewModel {
    private var cardDataService: CardDataService?
    private var previousBrightness: CGFloat = 0.5

    var group: CardGroup

    var cards: [Card] {
        group.sortedCards
    }

    init(group: CardGroup) {
        self.group = group
    }

    func setup(modelContext: ModelContext) {
        cardDataService = CardDataService(modelContext: modelContext)
    }

    func currentCardName(at index: Int) -> String {
        guard index >= 0 && index < cards.count else { return "" }
        return cards[index].name
    }

    func markCardAsUsed(at index: Int) {
        guard index >= 0 && index < cards.count else { return }
        cardDataService?.markCardAsUsed(cards[index])
    }

    func activateBrightnessBoost() {
        previousBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
    }

    func deactivateBrightnessBoost() {
        UIScreen.main.brightness = previousBrightness
    }
}
