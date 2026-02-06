//
//  CardDetailViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData
import PassKit

@MainActor
@Observable
final class CardDetailViewModel {
    private var cardDataService: CardDataService?
    private let passKitService = PassKitService.shared
    private let imageStorage = ImageStorageService.shared

    var card: Card
    var isEditing: Bool = false
    var editedName: String = ""
    var editedNotes: String = ""
    var isAddingToWallet: Bool = false
    var walletError: String?
    var showDeleteConfirmation: Bool = false
    var isBrightnessBoostEnabled: Bool = false

    var cardImage: UIImage? {
        guard !card.imagePath.isEmpty else { return nil }
        return imageStorage.loadImage(named: card.imagePath)
    }

    var canAddToWallet: Bool {
        card.isWalletCompatible && !card.isInWallet && passKitService.isWalletAvailable
    }

    init(card: Card) {
        self.card = card
        self.editedName = card.name
        self.editedNotes = card.notes
    }

    func setup(modelContext: ModelContext) {
        self.cardDataService = CardDataService(modelContext: modelContext)
    }

    func startEditing() {
        editedName = card.name
        editedNotes = card.notes
        isEditing = true
    }

    func saveChanges() {
        card.name = editedName
        card.notes = editedNotes
        cardDataService?.updateCard(card)
        isEditing = false
    }

    func cancelEditing() {
        editedName = card.name
        editedNotes = card.notes
        isEditing = false
    }

    func toggleFavorite() {
        cardDataService?.toggleFavorite(card)
    }

    func markAsUsed() {
        cardDataService?.markCardAsUsed(card)
    }

    func deleteCard() {
        cardDataService?.deleteCard(card)
    }

    func addToWallet() async {
        isAddingToWallet = true
        walletError = nil

        do {
            let pass = try await passKitService.createPass(for: card)

            await MainActor.run {
                presentAddPassController(pass: pass)
            }
        } catch {
            walletError = error.localizedDescription
            isAddingToWallet = false
        }
    }

    private func presentAddPassController(pass: PKPass) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            walletError = "Unable to present Wallet"
            isAddingToWallet = false
            return
        }

        let addPassController = PKAddPassesViewController(pass: pass)
        addPassController?.delegate = WalletDelegate.shared

        WalletDelegate.shared.onComplete = { [weak self] success in
            Task { @MainActor in
                if success {
                    self?.card.isInWallet = true
                    self?.cardDataService?.setWalletStatus(self!.card, isInWallet: true)
                }
                self?.isAddingToWallet = false
            }
        }

        rootViewController.present(addPassController!, animated: true)
    }

    func toggleBrightnessBoost() {
        isBrightnessBoostEnabled.toggle()

        if isBrightnessBoostEnabled {
            UIScreen.main.brightness = 1.0
        }
    }
}

private class WalletDelegate: NSObject, PKAddPassesViewControllerDelegate {
    static let shared = WalletDelegate()

    var onComplete: ((Bool) -> Void)?

    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        controller.dismiss(animated: true) {
            self.onComplete?(true)
        }
    }
}
