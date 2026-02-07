//
//  ManualEntryViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class ManualEntryViewModel {
    private var cardDataService: CardDataService?
    private let barcodeGenerator: any BarcodeGeneratorServiceProtocol

    init(barcodeGenerator: any BarcodeGeneratorServiceProtocol = BarcodeGeneratorService.shared) {
        self.barcodeGenerator = barcodeGenerator
    }

    var cardName: String = ""
    var barcodeData: String = ""
    var selectedFormat: BarcodeFormat = .qr
    var notes: String = ""

    var generatedImage: UIImage?
    var errorMessage: String?
    var isValid: Bool {
        !cardName.isEmpty && !barcodeData.isEmpty && barcodeGenerator.validateBarcodeData(barcodeData, for: selectedFormat)
    }

    var generatableFormats: [BarcodeFormat] {
        BarcodeFormat.allCases.filter { $0.canGenerate }
    }

    func setup(modelContext: ModelContext) {
        self.cardDataService = CardDataService(modelContext: modelContext)
    }

    func generatePreview() {
        guard !barcodeData.isEmpty else {
            generatedImage = nil
            return
        }

        generatedImage = barcodeGenerator.generateBarcode(data: barcodeData, format: selectedFormat)
    }

    func saveCard() -> Card? {
        guard isValid else {
            errorMessage = "Please fill in all required fields correctly"
            return nil
        }

        let image = barcodeGenerator.generateBarcode(data: barcodeData, format: selectedFormat)

        let card = cardDataService?.createCard(
            name: cardName,
            barcodeData: barcodeData,
            barcodeFormat: selectedFormat,
            image: image
        )

        if let card = card, !notes.isEmpty {
            card.notes = notes
            cardDataService?.updateCard(card)
        }

        return card
    }

    func reset() {
        cardName = ""
        barcodeData = ""
        selectedFormat = .qr
        notes = ""
        generatedImage = nil
        errorMessage = nil
    }
}
