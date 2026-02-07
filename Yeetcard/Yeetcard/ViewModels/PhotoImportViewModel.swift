//
//  PhotoImportViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData
import PhotosUI

@MainActor
@Observable
final class PhotoImportViewModel {
    enum ImportState {
        case pickingPhoto
        case detecting
        case detected(DetectedBarcode, UIImage)
        case noBarcodeFound
        case error(String)
    }

    private var cardDataService: CardDataService?
    private let barcodeDetectionService: any BarcodeDetectionServiceProtocol

    var state: ImportState = .pickingPhoto
    var selectedPhoto: PhotosPickerItem? {
        didSet {
            if selectedPhoto != nil {
                Task { await processSelectedPhoto() }
            }
        }
    }
    var cardName: String = ""

    private var detectedBarcode: DetectedBarcode?
    private var selectedImage: UIImage?

    init(barcodeDetectionService: any BarcodeDetectionServiceProtocol = BarcodeDetectionService()) {
        self.barcodeDetectionService = barcodeDetectionService
    }

    func setup(modelContext: ModelContext) {
        cardDataService = CardDataService(modelContext: modelContext)
    }

    private func processSelectedPhoto() async {
        guard let photo = selectedPhoto else { return }
        state = .detecting

        do {
            guard let data = try await photo.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                state = .error("Could not load image")
                return
            }

            let barcodes = await barcodeDetectionService.detectBarcodes(in: image)

            if let barcode = barcodes.first {
                selectedImage = image
                detectedBarcode = barcode
                state = .detected(barcode, image)
            } else {
                state = .noBarcodeFound
            }
        } catch {
            state = .error("Failed to process photo: \(error.localizedDescription)")
        }
    }

    func saveCard() {
        guard let barcode = detectedBarcode, let image = selectedImage else { return }

        _ = cardDataService?.createCard(
            name: cardName.isEmpty ? "Unnamed Card" : cardName,
            barcodeData: barcode.data,
            barcodeFormat: barcode.format,
            image: image
        )
    }

    func reset() {
        state = .pickingPhoto
        selectedPhoto = nil
        cardName = ""
        detectedBarcode = nil
        selectedImage = nil
    }
}
