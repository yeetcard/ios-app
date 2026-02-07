//
//  GalleryViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

enum GalleryItem: Identifiable {
    case card(Card)
    case group(CardGroup)

    var id: String {
        switch self {
        case .card(let card): return "card-\(card.id)"
        case .group(let group): return "group-\(group.id)"
        }
    }
}

@MainActor
@Observable
final class GalleryViewModel {
    private var cardDataService: CardDataService?

    var cards: [Card] = []
    var groups: [CardGroup] = []
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

    var ungroupedCards: [Card] {
        filteredCards.filter { $0.group == nil }
    }

    var filteredGroups: [CardGroup] {
        guard !searchText.isEmpty else { return groups }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(searchText) ||
            group.cards.contains { card in
                card.name.localizedCaseInsensitiveContains(searchText) ||
                card.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var galleryItems: [GalleryItem] {
        var items: [GalleryItem] = filteredGroups.map { .group($0) }
        items.append(contentsOf: ungroupedCards.map { .card($0) })
        return items
    }

    var isEmpty: Bool {
        galleryItems.isEmpty
    }

    func setup(modelContext: ModelContext) {
        self.cardDataService = CardDataService(modelContext: modelContext)
        loadCards()
    }

    func loadCards() {
        cards = filteredCards
        groups = cardDataService?.fetchAllGroups() ?? []
    }

    func deleteCard(_ card: Card) {
        cardDataService?.deleteCard(card)
        loadCards()
    }

    func deleteGroup(_ group: CardGroup) {
        cardDataService?.deleteGroup(group)
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
