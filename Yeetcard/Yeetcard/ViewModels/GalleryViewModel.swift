//
//  GalleryViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class GalleryViewModel {
    private var cardDataService: CardDataService?

    var cards: [Card] = []
    var searchText: String = ""
    var sortOption: CardSortOption = .dateAdded
    var showFavoritesOnly: Bool = false
    var isLoading: Bool = false

    var filteredCards: [Card] {
        cardDataService?.fetchCards(
            searchText: searchText,
            sortBy: sortOption,
            filterFavorites: showFavoritesOnly
        ) ?? []
    }

    func setup(modelContext: ModelContext) {
        self.cardDataService = CardDataService(modelContext: modelContext)
        loadCards()
    }

    func loadCards() {
        cards = filteredCards
    }

    func deleteCard(_ card: Card) {
        cardDataService?.deleteCard(card)
        loadCards()
    }

    func toggleFavorite(_ card: Card) {
        cardDataService?.toggleFavorite(card)
        loadCards()
    }

    func markAsUsed(_ card: Card) {
        cardDataService?.markCardAsUsed(card)
    }
}
