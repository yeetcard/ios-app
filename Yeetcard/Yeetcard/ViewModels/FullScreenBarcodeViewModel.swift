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
    private let barcodeGenerator: any BarcodeGeneratorServiceProtocol
    private let imageStorage: any ImageStorageServiceProtocol
    private var previousBrightness: CGFloat = 0.5

    var card: Card
    var showingRenderedBarcode: Bool = true

    var canToggleView: Bool {
        card.barcodeFormat.canGenerate && !card.imagePath.isEmpty
    }

    var renderedBarcodeImage: UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let size = barcodeSize(for: card.barcodeFormat, screenWidth: screenWidth)
        return barcodeGenerator.generateBarcode(data: card.barcodeData, format: card.barcodeFormat, size: size)
    }

    var originalPhoto: UIImage? {
        guard !card.imagePath.isEmpty else { return nil }
        return imageStorage.loadImage(named: card.imagePath)
    }

    init(
        card: Card,
        barcodeGenerator: any BarcodeGeneratorServiceProtocol = BarcodeGeneratorService.shared,
        imageStorage: any ImageStorageServiceProtocol = ImageStorageService.shared
    ) {
        self.card = card
        self.barcodeGenerator = barcodeGenerator
        self.imageStorage = imageStorage
        self.showingRenderedBarcode = card.barcodeFormat.canGenerate
    }

    func setup(modelContext: ModelContext) {
        cardDataService = CardDataService(modelContext: modelContext)
        cardDataService?.markCardAsUsed(card)
    }

    func toggleDisplayMode() {
        showingRenderedBarcode.toggle()
    }

    func activateBrightnessBoost() {
        previousBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
    }

    func deactivateBrightnessBoost() {
        UIScreen.main.brightness = previousBrightness
    }

    private func barcodeSize(for format: BarcodeFormat, screenWidth: CGFloat) -> CGSize {
        let scale = UIScreen.main.scale
        let pixelWidth = screenWidth * scale
        switch format {
        case .qr, .aztec:
            return CGSize(width: pixelWidth, height: pixelWidth)
        case .code128, .code39:
            return CGSize(width: pixelWidth, height: pixelWidth * 0.4)
        case .pdf417:
            return CGSize(width: pixelWidth, height: pixelWidth * 0.3)
        default:
            return CGSize(width: pixelWidth, height: pixelWidth)
        }
    }
}
