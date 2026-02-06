//
//  SettingsViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    private var cardDataService: CardDataService?
    private let authService = AuthenticationService.shared

    var cardCount: Int = 0
    var showDeleteAllConfirmation: Bool = false

    var biometricType: BiometricType {
        authService.availableBiometricType
    }

    var isBiometricsAvailable: Bool {
        authService.isBiometricsAvailable
    }

    var securityStatusText: String {
        if isBiometricsAvailable {
            return "\(biometricType.displayName) enabled"
        } else {
            return "Biometrics not available"
        }
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    func setup(modelContext: ModelContext) {
        self.cardDataService = CardDataService(modelContext: modelContext)
        loadCardCount()
    }

    func loadCardCount() {
        cardCount = cardDataService?.fetchAllCards().count ?? 0
    }

    func deleteAllCards() {
        let cards = cardDataService?.fetchAllCards() ?? []
        for card in cards {
            cardDataService?.deleteCard(card)
        }
        loadCardCount()
    }
}
