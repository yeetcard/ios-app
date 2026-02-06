//
//  CardDataService.swift
//  Yeetcard
//

import Foundation
import SwiftData
import UIKit

@MainActor
final class CardDataService {
    private let modelContext: ModelContext
    private let imageStorage = ImageStorageService.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllCards() -> [Card] {
        let descriptor = FetchDescriptor<Card>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchCards(searchText: String = "", sortBy: CardSortOption = .dateAdded, filterFavorites: Bool = false) -> [Card] {
        var descriptor = FetchDescriptor<Card>()

        switch sortBy {
        case .dateAdded:
            descriptor.sortBy = [SortDescriptor(\.dateAdded, order: .reverse)]
        case .name:
            descriptor.sortBy = [SortDescriptor(\.name, order: .forward)]
        case .lastUsed:
            descriptor.sortBy = [SortDescriptor(\.lastUsed, order: .reverse)]
        }

        var cards = (try? modelContext.fetch(descriptor)) ?? []

        if !searchText.isEmpty {
            cards = cards.filter { card in
                card.name.localizedCaseInsensitiveContains(searchText) ||
                card.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        if filterFavorites {
            cards = cards.filter { $0.isFavorite }
        }

        return cards
    }

    func createCard(name: String, barcodeData: String, barcodeFormat: BarcodeFormat, image: UIImage?) -> Card {
        let card = Card(
            name: name,
            barcodeData: barcodeData,
            barcodeFormat: barcodeFormat
        )

        if let image = image, let paths = imageStorage.saveImage(image, cardId: card.id) {
            card.imagePath = paths.imagePath
            card.thumbnailPath = paths.thumbnailPath
        }

        modelContext.insert(card)
        try? modelContext.save()

        return card
    }

    func updateCard(_ card: Card) {
        try? modelContext.save()
    }

    func updateCardImage(_ card: Card, image: UIImage) {
        if !card.imagePath.isEmpty {
            imageStorage.deleteImages(imagePath: card.imagePath, thumbnailPath: card.thumbnailPath)
        }

        if let paths = imageStorage.saveImage(image, cardId: card.id) {
            card.imagePath = paths.imagePath
            card.thumbnailPath = paths.thumbnailPath
        }

        try? modelContext.save()
    }

    func deleteCard(_ card: Card) {
        if !card.imagePath.isEmpty {
            imageStorage.deleteImages(imagePath: card.imagePath, thumbnailPath: card.thumbnailPath)
        }
        modelContext.delete(card)
        try? modelContext.save()
    }

    func markCardAsUsed(_ card: Card) {
        card.lastUsed = Date()
        try? modelContext.save()
    }

    func toggleFavorite(_ card: Card) {
        card.isFavorite.toggle()
        try? modelContext.save()
    }

    func setWalletStatus(_ card: Card, isInWallet: Bool) {
        card.isInWallet = isInWallet
        try? modelContext.save()
    }
}

enum CardSortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case name = "Name"
    case lastUsed = "Last Used"
}
