//
//  GroupManagementViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class GroupManagementViewModel {
    private var modelContext: ModelContext?
    private var cardDataService: CardDataService?

    var groupName: String = ""
    var selectedCards: [Card] = []
    var availableCards: [Card] = []
    var isEditing: Bool = false

    private var existingGroup: CardGroup?

    var isValid: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty && selectedCards.count >= 2
    }

    init(group: CardGroup? = nil) {
        if let group = group {
            self.existingGroup = group
            self.groupName = group.name
            self.selectedCards = group.sortedCards
            self.isEditing = true
        }
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.cardDataService = CardDataService(modelContext: modelContext)
        loadAvailableCards()
    }

    private func loadAvailableCards() {
        let allCards = cardDataService?.fetchAllCards() ?? []
        let selectedIds = Set(selectedCards.map { $0.id })
        availableCards = allCards.filter { card in
            !selectedIds.contains(card.id) && card.group == nil
        }
    }

    func addCard(_ card: Card) {
        selectedCards.append(card)
        availableCards.removeAll { $0.id == card.id }
    }

    func removeCard(_ card: Card) {
        selectedCards.removeAll { $0.id == card.id }
        availableCards.append(card)
    }

    func save() {
        guard let modelContext = modelContext else { return }

        if let group = existingGroup {
            group.name = groupName
            group.cards = selectedCards
        } else {
            let group = CardGroup(name: groupName, cards: selectedCards)
            modelContext.insert(group)
        }

        try? modelContext.save()
    }
}
