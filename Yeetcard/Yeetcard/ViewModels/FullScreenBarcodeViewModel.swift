//
//  FullScreenBarcodeViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class FullScreenBarcodeViewModel {
    private var cardDataService: CardDataService?
    private var previousBrightness: CGFloat = 0.5

    var card: Card

    init(card: Card) {
        self.card = card
    }

    func setup(modelContext: ModelContext) {
        cardDataService = CardDataService(modelContext: modelContext)
        cardDataService?.markCardAsUsed(card)
    }

    func activateBrightnessBoost() {
        previousBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
    }

    func deactivateBrightnessBoost() {
        UIScreen.main.brightness = previousBrightness
    }
}
