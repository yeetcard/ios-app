//
//  YeetcardTests.swift
//  YeetcardTests
//
//  Created by Rishi Malik on 12/9/25.
//

import Testing
import SwiftData
import UIKit
import PassKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation
@testable import Yeetcard

// MARK: - Mock Services

final class MockAuthenticationService: AuthenticationServiceProtocol {
    var availableBiometricType: BiometricType = .faceID
    var isBiometricsAvailable: Bool = true
    var shouldSucceed: Bool = true
    var errorToThrow: Error = AuthenticationError.authenticationFailed

    func authenticate() async throws {
        guard shouldSucceed else { throw errorToThrow }
    }
}

final class MockBarcodeGenerator: BarcodeGeneratorServiceProtocol {
    var imageToReturn: UIImage? = UIImage(systemName: "qrcode")
    var validationResult: Bool = true

    func generateBarcode(data: String, format: BarcodeFormat, size: CGSize) -> UIImage? {
        imageToReturn
    }

    func validateBarcodeData(_ data: String, for format: BarcodeFormat) -> Bool {
        validationResult
    }
}

final class MockImageStorage: ImageStorageServiceProtocol {
    var savedImages: [UUID: UIImage] = [:]
    var savedPaths: [UUID: (imagePath: String, thumbnailPath: String)] = [:]

    func saveImage(_ image: UIImage, cardId: UUID) -> (imagePath: String, thumbnailPath: String)? {
        savedImages[cardId] = image
        let paths = (imagePath: "\(cardId.uuidString).jpg", thumbnailPath: "\(cardId.uuidString)_thumb.jpg")
        savedPaths[cardId] = paths
        return paths
    }

    func loadImage(named name: String) -> UIImage? {
        savedImages.values.first
    }

    func deleteImages(imagePath: String, thumbnailPath: String) {
        savedImages.removeAll()
        savedPaths.removeAll()
    }

    func getFullPath(for imageName: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(imageName)")
    }
}

final class MockCameraService: CameraServiceProtocol {
    weak var delegate: (any CameraServiceDelegate)?

    private let dummySession = AVCaptureSession()
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        AVCaptureVideoPreviewLayer(session: dummySession)
    }()

    var isFlashAvailable: Bool = true
    var isFlashOn: Bool = false

    var setupSessionCalled = false
    var startSessionCalled = false
    var stopSessionCalled = false
    var capturePhotoCalled = false
    var toggleFlashCalled = false

    var setupSessionError: Error?

    func setupSession() async throws {
        setupSessionCalled = true
        if let error = setupSessionError {
            throw error
        }
    }

    func startSession() {
        startSessionCalled = true
    }

    func stopSession() {
        stopSessionCalled = true
    }

    func capturePhoto() {
        capturePhotoCalled = true
    }

    func toggleFlash() {
        toggleFlashCalled = true
        isFlashOn.toggle()
    }
}

final class MockAudioDetectionService: AudioDetectionServiceProtocol {
    var isListening: Bool = false
    var onSpikeDetected: (() -> Void)?

    var startListeningCalled = false
    var stopListeningCalled = false
    var startListeningError: Error?

    static var permissionResult: Bool = true

    static func checkPermission() async -> Bool {
        return permissionResult
    }

    func startListening() throws {
        startListeningCalled = true
        if let error = startListeningError {
            throw error
        }
        isListening = true
    }

    func stopListening() {
        stopListeningCalled = true
        isListening = false
    }

    func simulateSpike() {
        onSpikeDetected?()
    }
}

final class MockTapDetectionService: TapDetectionServiceProtocol {
    var isDetecting: Bool = false
    var onTapDetected: (() -> Void)?
    var onDebugUpdate: ((TapDebugInfo) -> Void)?

    var startDetectingCalled = false
    var stopDetectingCalled = false

    func startDetecting() {
        startDetectingCalled = true
        isDetecting = true
    }

    func stopDetecting() {
        stopDetectingCalled = true
        isDetecting = false
    }

    func simulateTap() {
        onTapDetected?()
    }
}

final class MockPassKitService: PassKitServiceProtocol {
    var isWalletAvailable: Bool = true
    var shouldSucceed: Bool = false

    func createPass(for card: Card, foregroundColor: String, backgroundColor: String) async throws -> PKPass {
        throw PassKitError.notSupported
    }

    func isCardInWallet(card: Card) -> Bool {
        false
    }
}

// MARK: - Helper

func makeInMemoryModelContext() throws -> ModelContext {
    let schema = Schema([Card.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - BarcodeFormat Tests

@Suite("BarcodeFormat")
struct BarcodeFormatTests {
    @Test func displayNamesAreNonEmpty() {
        for format in BarcodeFormat.allCases {
            #expect(!format.displayName.isEmpty, "displayName should not be empty for \(format)")
        }
    }

    @Test func canGenerateFormats() {
        let expected: Set<BarcodeFormat> = [.qr, .code128, .pdf417, .aztec, .code39, .ean13]
        let actual = Set(BarcodeFormat.allCases.filter { $0.canGenerate })
        #expect(actual == expected)
    }

    @Test func walletCompatibleFormats() {
        let expected: Set<BarcodeFormat> = [.qr, .code128, .pdf417, .aztec]
        let actual = Set(BarcodeFormat.allCases.filter { $0.isWalletCompatible })
        #expect(actual == expected)
    }

    @Test func rawValueRoundtrip() {
        for format in BarcodeFormat.allCases {
            let recovered = BarcodeFormat(rawValue: format.rawValue)
            #expect(recovered == format)
        }
    }
}

// MARK: - Card Model Tests

@Suite("Card Model")
struct CardModelTests {
    @Test func initSetsProperties() {
        let card = Card(name: "Test", barcodeData: "12345", barcodeFormat: .code128)
        #expect(card.name == "Test")
        #expect(card.barcodeData == "12345")
        #expect(card.barcodeFormat == .code128)
        #expect(card.isFavorite == false)
        #expect(card.isInWallet == false)
        #expect(card.notes == "")
    }

    @Test func barcodeFormatComputedProperty() {
        let card = Card(name: "Test", barcodeData: "data", barcodeFormat: .qr)
        #expect(card.barcodeFormat == .qr)
        #expect(card.barcodeFormatRaw == "QR")

        card.barcodeFormat = .aztec
        #expect(card.barcodeFormatRaw == "Aztec")
        #expect(card.barcodeFormat == .aztec)
    }

    @Test func walletCompatibility() {
        let qrCard = Card(name: "QR", barcodeData: "data", barcodeFormat: .qr)
        #expect(qrCard.isWalletCompatible == true)

        let ean13Card = Card(name: "EAN", barcodeData: "1234567890123", barcodeFormat: .ean13)
        #expect(ean13Card.isWalletCompatible == false)
    }

    @Test func allFormatsCreateCards() {
        for format in BarcodeFormat.allCases {
            let card = Card(name: "Card-\(format.rawValue)", barcodeData: "data", barcodeFormat: format)
            #expect(card.barcodeFormat == format)
        }
    }
}

// MARK: - AuthenticationViewModel Tests

@Suite("AuthenticationViewModel")
struct AuthenticationViewModelTests {
    @Test @MainActor func successfulAuthSetsAuthenticated() async {
        let mock = MockAuthenticationService()
        mock.shouldSucceed = true
        let vm = AuthenticationViewModel(authService: mock)

        await vm.authenticate()

        #expect(vm.isAuthenticated == true)
        #expect(vm.errorMessage == nil)
        #expect(vm.showRetryButton == false)
        #expect(vm.isAuthenticating == false)
    }

    @Test @MainActor func failedAuthShowsError() async {
        let mock = MockAuthenticationService()
        mock.shouldSucceed = false
        mock.errorToThrow = AuthenticationError.authenticationFailed
        let vm = AuthenticationViewModel(authService: mock)

        await vm.authenticate()

        #expect(vm.isAuthenticated == false)
        #expect(vm.errorMessage != nil)
        #expect(vm.showRetryButton == true)
    }

    @Test @MainActor func biometricsUnavailableAutoAuthenticates() async {
        let mock = MockAuthenticationService()
        mock.isBiometricsAvailable = false
        let vm = AuthenticationViewModel(authService: mock)

        await vm.authenticate()

        #expect(vm.isAuthenticated == true)
    }

    @Test @MainActor func userCancelShowsError() async {
        let mock = MockAuthenticationService()
        mock.shouldSucceed = false
        mock.errorToThrow = AuthenticationError.userCancelled
        let vm = AuthenticationViewModel(authService: mock)

        await vm.authenticate()

        #expect(vm.isAuthenticated == false)
        #expect(vm.errorMessage == AuthenticationError.userCancelled.errorDescription)
        #expect(vm.showRetryButton == true)
    }

    @Test @MainActor func resetClearsState() async {
        let mock = MockAuthenticationService()
        mock.shouldSucceed = true
        let vm = AuthenticationViewModel(authService: mock)

        await vm.authenticate()
        #expect(vm.isAuthenticated == true)

        vm.reset()
        #expect(vm.isAuthenticated == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.showRetryButton == false)
    }

    @Test @MainActor func promptTextMatchesBiometricType() {
        let mock = MockAuthenticationService()

        mock.availableBiometricType = .faceID
        let vm1 = AuthenticationViewModel(authService: mock)
        #expect(vm1.promptText == "Use Face ID to unlock")

        mock.availableBiometricType = .touchID
        let vm2 = AuthenticationViewModel(authService: mock)
        #expect(vm2.promptText == "Use Touch ID to unlock")

        mock.availableBiometricType = .none
        let vm3 = AuthenticationViewModel(authService: mock)
        #expect(vm3.promptText == "Biometrics unavailable")
    }

    @Test @MainActor func iconNameMatchesBiometricType() {
        let mock = MockAuthenticationService()

        mock.availableBiometricType = .faceID
        let vm = AuthenticationViewModel(authService: mock)
        #expect(vm.iconName == "faceid")

        mock.availableBiometricType = .touchID
        let vm2 = AuthenticationViewModel(authService: mock)
        #expect(vm2.iconName == "touchid")
    }
}

// MARK: - BarcodeGeneratorService Tests

@Suite("BarcodeGeneratorService", .serialized)
struct BarcodeGeneratorServiceTests {
    let service = BarcodeGeneratorService.shared

    @Test func generatesQRCode() {
        let image = service.generateBarcode(data: "Hello World", format: .qr)
        #expect(image != nil)
        #expect(image!.size.width > 0)
        #expect(image!.size.height > 0)
    }

    @Test func generatesCode128() {
        let image = service.generateBarcode(data: "12345", format: .code128)
        #expect(image != nil)
    }

    @Test func generatesPDF417() {
        let image = service.generateBarcode(data: "Test Data", format: .pdf417)
        #expect(image != nil)
    }

    @Test func generatesAztec() {
        let image = service.generateBarcode(data: "Aztec Test", format: .aztec)
        #expect(image != nil)
    }

    @Test func generatesCode39() {
        let image = service.generateBarcode(data: "HELLO", format: .code39)
        #expect(image != nil)
        #expect(image!.size.width > 0)
        #expect(image!.size.height > 0)
    }

    @Test func generatesEAN13() {
        let image = service.generateBarcode(data: "5901234123457", format: .ean13)
        #expect(image != nil)
        #expect(image!.size.width > 0)
        #expect(image!.size.height > 0)
    }

    @Test func returnsNilForNonGeneratableFormats() {
        #expect(service.generateBarcode(data: "12345", format: .dataMatrix) == nil)
    }

    @Test func returnsNilForInvalidEAN13() {
        #expect(service.generateBarcode(data: "12345", format: .ean13) == nil)
        #expect(service.generateBarcode(data: "abcdefghijklm", format: .ean13) == nil)
    }

    @Test func returnsNilForInvalidCode39() {
        #expect(service.generateBarcode(data: "invalid{char}", format: .code39) == nil)
    }

    @Test func respectsCustomSize() {
        let size = CGSize(width: 500, height: 500)
        let image = service.generateBarcode(data: "Test", format: .qr, size: size)
        #expect(image != nil)
    }

    @Test func validateEAN13() {
        #expect(service.validateBarcodeData("1234567890123", for: .ean13) == true)
        #expect(service.validateBarcodeData("123456789012", for: .ean13) == false)
        #expect(service.validateBarcodeData("123456789012a", for: .ean13) == false)
    }

    @Test func validateEAN8() {
        #expect(service.validateBarcodeData("12345678", for: .ean8) == true)
        #expect(service.validateBarcodeData("1234567", for: .ean8) == false)
    }

    @Test func validateUPCA() {
        #expect(service.validateBarcodeData("123456789012", for: .upcA) == true)
        #expect(service.validateBarcodeData("12345678901", for: .upcA) == false)
    }

    @Test func validateUPCE() {
        #expect(service.validateBarcodeData("12345678", for: .upcE) == true)
        #expect(service.validateBarcodeData("1234567", for: .upcE) == false)
    }

    @Test func validateRejectsEmpty() {
        for format in BarcodeFormat.allCases {
            #expect(service.validateBarcodeData("", for: format) == false)
        }
    }

    @Test func validateAcceptsAnyStringForFlexibleFormats() {
        let flexibleFormats: [BarcodeFormat] = [.qr, .code128, .code39, .pdf417, .aztec, .dataMatrix]
        for format in flexibleFormats {
            #expect(service.validateBarcodeData("anything", for: format) == true)
        }
    }
}

// MARK: - ManualEntryViewModel Tests

@Suite("ManualEntryViewModel")
struct ManualEntryViewModelTests {
    @Test @MainActor func isValidRequiresNameAndData() {
        let vm = ManualEntryViewModel()
        #expect(vm.isValid == false)

        vm.cardName = "Test"
        #expect(vm.isValid == false)

        vm.barcodeData = "12345"
        #expect(vm.isValid == true)
    }

    @Test @MainActor func isValidRespectsFormatValidation() {
        let vm = ManualEntryViewModel()
        vm.cardName = "Test"
        vm.barcodeData = "12345"
        vm.selectedFormat = .qr
        #expect(vm.isValid == true)
    }

    @Test @MainActor func generatePreviewProducesImage() {
        let vm = ManualEntryViewModel()
        vm.barcodeData = "Hello"
        vm.selectedFormat = .qr
        vm.generatePreview()
        #expect(vm.generatedImage != nil)
    }

    @Test @MainActor func generatePreviewClearsOnEmptyData() {
        let vm = ManualEntryViewModel()
        vm.barcodeData = "Hello"
        vm.generatePreview()
        #expect(vm.generatedImage != nil)

        vm.barcodeData = ""
        vm.generatePreview()
        #expect(vm.generatedImage == nil)
    }

    @Test @MainActor func generatableFormatsOnlyIncludesCanGenerate() {
        let vm = ManualEntryViewModel()
        let formats = vm.generatableFormats
        for format in formats {
            #expect(format.canGenerate == true)
        }
        #expect(formats.count == 6) // QR, Code128, PDF417, Aztec, Code39, EAN-13
    }

    @Test @MainActor func resetClearsAllFields() {
        let vm = ManualEntryViewModel()
        vm.cardName = "Test"
        vm.barcodeData = "12345"
        vm.notes = "Some notes"
        vm.selectedFormat = .aztec
        vm.errorMessage = "Error"

        vm.reset()

        #expect(vm.cardName == "")
        #expect(vm.barcodeData == "")
        #expect(vm.notes == "")
        #expect(vm.selectedFormat == .qr)
        #expect(vm.errorMessage == nil)
        #expect(vm.generatedImage == nil)
    }

    @Test @MainActor func saveCardFailsWhenInvalid() {
        let vm = ManualEntryViewModel()
        let result = vm.saveCard()
        #expect(result == nil)
        #expect(vm.errorMessage != nil)
    }
}

// MARK: - CardDataService Tests

@Suite("CardDataService")
struct CardDataServiceTests {
    @Test @MainActor func createCardPersists() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        let card = service.createCard(name: "Test Card", barcodeData: "12345", barcodeFormat: .qr, image: nil)

        #expect(card.name == "Test Card")
        #expect(card.barcodeData == "12345")
        #expect(card.barcodeFormat == .qr)

        let fetched = service.fetchAllCards()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Card")
    }

    @Test @MainActor func fetchCardsReturnsCreated() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        _ = service.createCard(name: "Card A", barcodeData: "aaa", barcodeFormat: .qr, image: nil)
        _ = service.createCard(name: "Card B", barcodeData: "bbb", barcodeFormat: .code128, image: nil)

        let cards = service.fetchAllCards()
        #expect(cards.count == 2)
    }

    @Test @MainActor func deleteCardRemoves() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        let card = service.createCard(name: "Delete Me", barcodeData: "data", barcodeFormat: .qr, image: nil)
        #expect(service.fetchAllCards().count == 1)

        service.deleteCard(card)
        #expect(service.fetchAllCards().count == 0)
    }

    @Test @MainActor func toggleFavorite() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        let card = service.createCard(name: "Fav Card", barcodeData: "data", barcodeFormat: .qr, image: nil)
        #expect(card.isFavorite == false)

        service.toggleFavorite(card)
        #expect(card.isFavorite == true)

        service.toggleFavorite(card)
        #expect(card.isFavorite == false)
    }

    @Test @MainActor func searchFiltersByName() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        _ = service.createCard(name: "Costco Card", barcodeData: "111", barcodeFormat: .qr, image: nil)
        _ = service.createCard(name: "Gym Pass", barcodeData: "222", barcodeFormat: .qr, image: nil)

        let results = service.fetchCards(searchText: "Costco")
        #expect(results.count == 1)
        #expect(results.first?.name == "Costco Card")
    }

    @Test @MainActor func filterFavoritesOnly() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        let card1 = service.createCard(name: "Card 1", barcodeData: "111", barcodeFormat: .qr, image: nil)
        _ = service.createCard(name: "Card 2", barcodeData: "222", barcodeFormat: .qr, image: nil)

        service.toggleFavorite(card1)

        let favorites = service.fetchCards(filterFavorites: true)
        #expect(favorites.count == 1)
        #expect(favorites.first?.name == "Card 1")
    }

    @Test @MainActor func sortByName() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        _ = service.createCard(name: "Zebra", barcodeData: "111", barcodeFormat: .qr, image: nil)
        _ = service.createCard(name: "Alpha", barcodeData: "222", barcodeFormat: .qr, image: nil)

        let sorted = service.fetchCards(sortBy: .name)
        #expect(sorted.first?.name == "Alpha")
        #expect(sorted.last?.name == "Zebra")
    }

    @Test @MainActor func markCardAsUsed() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        let card = service.createCard(name: "Card", barcodeData: "data", barcodeFormat: .qr, image: nil)
        #expect(card.lastUsed == nil)

        service.markCardAsUsed(card)
        #expect(card.lastUsed != nil)
    }

    @Test @MainActor func setWalletStatus() throws {
        let context = try makeInMemoryModelContext()
        let service = CardDataService(modelContext: context)

        let card = service.createCard(name: "Card", barcodeData: "data", barcodeFormat: .qr, image: nil)
        #expect(card.isInWallet == false)

        service.setWalletStatus(card, isInWallet: true)
        #expect(card.isInWallet == true)
    }
}

// MARK: - BarcodeDetectionService Tests

@Suite("BarcodeDetectionService", .serialized)
struct BarcodeDetectionServiceTests {
    /// Generate a barcode entirely from scratch (no shared state) with white quiet zone
    private func generateTestBarcode(data: String, format: BarcodeFormat) -> UIImage? {
        // Create CIFilter and CIContext completely independently
        let ciContext = CIContext(options: [.useSoftwareRenderer: true])
        var ciImage: CIImage?

        switch format {
        case .qr:
            guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
            filter.setValue(Data(data.utf8), forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            ciImage = filter.outputImage
        case .code128:
            guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
            filter.setValue(Data(data.utf8), forKey: "inputMessage")
            filter.setValue(10.0, forKey: "inputQuietSpace")
            ciImage = filter.outputImage
        case .aztec:
            guard let filter = CIFilter(name: "CIAztecCodeGenerator") else { return nil }
            filter.setValue(Data(data.utf8), forKey: "inputMessage")
            filter.setValue(23.0, forKey: "inputCorrectionLevel")
            ciImage = filter.outputImage
        default:
            return nil
        }

        guard let ci = ciImage else { return nil }

        // Scale up for reliable detection (10x)
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        // Add white quiet zone
        let padding: CGFloat = 80
        let shifted = scaled.transformed(by: CGAffineTransform(translationX: padding, y: padding))
        let canvas = CGRect(x: 0, y: 0, width: shifted.extent.maxX + padding, height: shifted.extent.maxY + padding)
        let white = CIImage(color: .white).cropped(to: canvas)
        let composited = shifted.composited(over: white)

        // Render to CGImage using software renderer
        guard let cgImage = ciContext.createCGImage(composited, from: canvas) else { return nil }

        // Round-trip through PNG data to ensure clean data-backed UIImage
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.pngData(), let clean = UIImage(data: data) else { return uiImage }
        return clean
    }

    /// Detect barcodes directly using Vision, bypassing BarcodeDetectionService
    private func detectDirectly(in image: UIImage) -> [VNBarcodeObservation] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return request.results ?? []
    }

    @Test(.disabled("Vision framework returns 0 results when CIFilter-heavy tests run in same process on simulator; passes in isolation"))
    func detectQRFromGeneratedImage() {
        guard let qrImage = generateTestBarcode(data: "Hello Test 123", format: .qr) else {
            Issue.record("Failed to generate QR image")
            return
        }

        let results = detectDirectly(in: qrImage)
        #expect(results.count >= 1)
        if let first = results.first {
            #expect(first.payloadStringValue == "Hello Test 123")
        }
    }

    @Test(.disabled("Vision framework returns 0 results when CIFilter-heavy tests run in same process on simulator; passes in isolation"))
    func detectCode128FromGeneratedImage() {
        guard let image = generateTestBarcode(data: "ABC123", format: .code128) else {
            Issue.record("Failed to generate Code128 image")
            return
        }

        let results = detectDirectly(in: image)
        #expect(results.count >= 1)
        if let first = results.first {
            #expect(first.payloadStringValue == "ABC123")
        }
    }

    @Test func returnsEmptyForBlankImage() async {
        let detector = BarcodeDetectionService()
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: fmt)
        let blankImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        let results = await detector.detectBarcodes(in: blankImage)
        #expect(results.isEmpty)
    }

    @Test(.disabled("Vision framework returns 0 results when CIFilter-heavy tests run in same process on simulator; passes in isolation"))
    func detectAztecFromGeneratedImage() {
        guard let image = generateTestBarcode(data: "AztecData", format: .aztec) else {
            Issue.record("Failed to generate Aztec image")
            return
        }

        let results = detectDirectly(in: image)
        #expect(results.count >= 1)
        if let first = results.first {
            #expect(first.payloadStringValue == "AztecData")
        }
    }
}

// MARK: - ImageStorageService Tests

@Suite("ImageStorageService", .serialized)
struct ImageStorageServiceTests {
    @Test func saveAndLoadRoundtrip() {
        let service = ImageStorageService.shared
        let cardId = UUID()

        // Create a simple 1x scale image to avoid scale factor issues
        let size = CGSize(width: 100, height: 100)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let testImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        guard let paths = service.saveImage(testImage, cardId: cardId) else {
            Issue.record("Failed to save image")
            return
        }

        #expect(!paths.imagePath.isEmpty)
        #expect(!paths.thumbnailPath.isEmpty)

        let loaded = service.loadImage(named: paths.imagePath)
        #expect(loaded != nil)

        let thumbnail = service.loadImage(named: paths.thumbnailPath)
        #expect(thumbnail != nil)

        // Cleanup
        service.deleteImages(imagePath: paths.imagePath, thumbnailPath: paths.thumbnailPath)
    }

    @Test func deleteRemovesFiles() {
        let service = ImageStorageService.shared
        let cardId = UUID()

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        let testImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }

        guard let paths = service.saveImage(testImage, cardId: cardId) else {
            Issue.record("Failed to save image")
            return
        }

        service.deleteImages(imagePath: paths.imagePath, thumbnailPath: paths.thumbnailPath)

        #expect(service.loadImage(named: paths.imagePath) == nil)
        #expect(service.loadImage(named: paths.thumbnailPath) == nil)
    }

    @Test func loadNonexistentReturnsNil() {
        let service = ImageStorageService.shared
        let result = service.loadImage(named: "nonexistent_image.jpg")
        #expect(result == nil)
    }
}

// MARK: - CardDetailViewModel Tests

@Suite("CardDetailViewModel")
struct CardDetailViewModelTests {
    @Test @MainActor func initSetsEditedFields() {
        let card = Card(name: "My Card", barcodeData: "data", barcodeFormat: .qr)
        card.notes = "Some notes"
        let vm = CardDetailViewModel(card: card)

        #expect(vm.editedName == "My Card")
        #expect(vm.editedNotes == "Some notes")
        #expect(vm.isEditing == false)
    }

    @Test @MainActor func startEditingCopiesValues() {
        let card = Card(name: "Card", barcodeData: "data", barcodeFormat: .qr)
        let vm = CardDetailViewModel(card: card)

        vm.startEditing()
        #expect(vm.isEditing == true)
        #expect(vm.editedName == "Card")
    }

    @Test @MainActor func cancelEditingRestoresValues() {
        let card = Card(name: "Original", barcodeData: "data", barcodeFormat: .qr)
        let vm = CardDetailViewModel(card: card)

        vm.startEditing()
        vm.editedName = "Changed"
        vm.cancelEditing()

        #expect(vm.editedName == "Original")
        #expect(vm.isEditing == false)
    }

    @Test @MainActor func canAddToWalletChecksCompatibility() {
        let mockPassKit = MockPassKitService()
        mockPassKit.isWalletAvailable = true

        let qrCard = Card(name: "QR", barcodeData: "data", barcodeFormat: .qr)
        let vm1 = CardDetailViewModel(card: qrCard, passKitService: mockPassKit)
        #expect(vm1.canAddToWallet == true)

        let eanCard = Card(name: "EAN", barcodeData: "1234567890123", barcodeFormat: .ean13)
        let vm2 = CardDetailViewModel(card: eanCard, passKitService: mockPassKit)
        #expect(vm2.canAddToWallet == false)
    }

    @Test @MainActor func canAddToWalletFalseWhenAlreadyInWallet() {
        let mockPassKit = MockPassKitService()
        mockPassKit.isWalletAvailable = true

        let card = Card(name: "QR", barcodeData: "data", barcodeFormat: .qr, isInWallet: true)
        let vm = CardDetailViewModel(card: card, passKitService: mockPassKit)
        #expect(vm.canAddToWallet == false)
    }

    @Test @MainActor func canAddToWalletFalseWhenWalletUnavailable() {
        let mockPassKit = MockPassKitService()
        mockPassKit.isWalletAvailable = false

        let card = Card(name: "QR", barcodeData: "data", barcodeFormat: .qr)
        let vm = CardDetailViewModel(card: card, passKitService: mockPassKit)
        #expect(vm.canAddToWallet == false)
    }

    @Test @MainActor func cardImageWithMockStorage() {
        let mockStorage = MockImageStorage()
        let testImage = UIImage(systemName: "star")!
        let cardId = UUID()
        mockStorage.savedImages[cardId] = testImage

        let card = Card(id: cardId, name: "Card", barcodeData: "data", barcodeFormat: .qr, imagePath: "test.jpg")
        let vm = CardDetailViewModel(card: card, imageStorage: mockStorage)

        #expect(vm.cardImage != nil)
    }

    @Test @MainActor func cardImageNilWhenNoPath() {
        let card = Card(name: "Card", barcodeData: "data", barcodeFormat: .qr)
        let vm = CardDetailViewModel(card: card)
        #expect(vm.cardImage == nil)
    }
}

// MARK: - CameraService Tests

@Suite("CameraService")
struct CameraServiceTests {
    @Test func previewLayerReturnsSameInstance() {
        let service = CameraService()
        let layer1 = service.previewLayer
        let layer2 = service.previewLayer
        #expect(layer1 === layer2, "previewLayer must return the same instance every time — creating a new layer per access causes the camera to freeze")
    }

    @Test func setupSessionIsAsync() async {
        // Verify setupSession doesn't block the caller by confirming it runs
        // asynchronously. On the simulator there's no camera, so it throws
        // cameraUnavailable — the important thing is it returns without freezing.
        let service = CameraService()
        do {
            try await service.setupSession()
            // If a camera is available (physical device), success is fine
        } catch {
            // Expected on simulator — cameraUnavailable
            #expect(error is CameraError)
        }
    }
}

// MARK: - ScannerViewModel Tests

@Suite("ScannerViewModel")
struct ScannerViewModelTests {
    @Test @MainActor func startScanningSetsStateAndStartsSession() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock)
        vm.hasPermission = true

        vm.startScanning()

        #expect(vm.state == .scanning)
        #expect(mock.startSessionCalled)
    }

    @Test @MainActor func startScanningRequiresPermission() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock)

        vm.startScanning()

        #expect(vm.state == .idle)
        #expect(!mock.startSessionCalled)
    }

    @Test @MainActor func stopScanningSetsIdleAndStopsSession() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock)
        vm.hasPermission = true
        vm.startScanning()

        vm.stopScanning()

        #expect(vm.state == .idle)
        #expect(mock.stopSessionCalled)
    }

    @Test @MainActor func firstBarcodeDetectionStartsTimerButDoesNotTransition() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 0)
        vm.hasPermission = true
        vm.startScanning()

        let barcode = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        vm.processBarcodeDetections([barcode])

        // First detection records the barcode and starts the timer, but doesn't transition
        #expect(vm.state == .scanning)
        #expect(!mock.capturePhotoCalled)
    }

    @Test @MainActor func consistentDetectionTriggersDetectedStateAndCapture() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 0)
        vm.hasPermission = true
        vm.startScanning()

        let barcode = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        // First: starts timer
        vm.processBarcodeDetections([barcode])
        // Second: same barcode, duration elapsed (0s) → detected
        vm.processBarcodeDetections([barcode])

        #expect(vm.state == .detected(barcode))
        #expect(mock.capturePhotoCalled, "capturePhoto should be called when barcode is confirmed")
    }

    @Test @MainActor func differentBarcodeResetsDetectionTimer() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 0)
        vm.hasPermission = true
        vm.startScanning()

        let barcode1 = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        let barcode2 = DetectedBarcode(data: "67890", format: .qr, boundingBox: .zero)

        vm.processBarcodeDetections([barcode1])
        vm.processBarcodeDetections([barcode2])

        #expect(vm.state == .scanning, "Different barcode should reset detection, not trigger capture")
        #expect(!mock.capturePhotoCalled)
    }

    @Test @MainActor func emptyDetectionResetsTracking() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 0)
        vm.hasPermission = true
        vm.startScanning()

        let barcode = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        vm.processBarcodeDetections([barcode])
        // No barcodes seen — resets tracking
        vm.processBarcodeDetections([])
        // Same barcode again should start fresh (not trigger detection)
        vm.processBarcodeDetections([barcode])

        #expect(vm.state == .scanning)
        #expect(!mock.capturePhotoCalled)
    }

    @Test @MainActor func handlePhotoCapturedTransitionsToCapturedState() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 0)
        vm.hasPermission = true
        vm.startScanning()

        let barcode = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        vm.processBarcodeDetections([barcode])
        vm.processBarcodeDetections([barcode])
        #expect(vm.state == .detected(barcode))

        let testImage = UIImage(systemName: "star")!
        vm.handlePhotoCaptured(testImage)

        if case .captured(_, let capturedBarcode) = vm.state {
            #expect(capturedBarcode.data == "12345")
        } else {
            Issue.record("Expected .captured state but got \(vm.state)")
        }
    }

    @Test @MainActor func handlePhotoCapturedIgnoredIfNotDetected() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock)
        vm.hasPermission = true
        vm.startScanning()

        let testImage = UIImage(systemName: "star")!
        vm.handlePhotoCaptured(testImage)

        #expect(vm.state == .scanning, "Photo should be ignored when not in .detected state")
    }

    @Test @MainActor func handleErrorSetsErrorState() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock)

        vm.handleError(.cameraUnavailable)

        #expect(vm.state == .error("Camera is not available on this device"))
    }

    @Test @MainActor func resetReturnsToScanning() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 0)
        vm.hasPermission = true
        vm.startScanning()

        let barcode = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        vm.processBarcodeDetections([barcode])
        vm.processBarcodeDetections([barcode])
        #expect(vm.state == .detected(barcode))

        vm.reset()

        #expect(vm.state == .scanning)
    }

    @Test @MainActor func toggleFlashDelegatesToCameraService() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock)

        vm.toggleFlash()

        #expect(mock.toggleFlashCalled)
        #expect(vm.isFlashOn == true)
    }

    @Test @MainActor func processBarcodesIgnoredWhenNotScanning() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 0)
        // state is .idle (no startScanning called)

        let barcode = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        vm.processBarcodeDetections([barcode])
        vm.processBarcodeDetections([barcode])

        #expect(vm.state == .idle, "Barcode processing should be ignored when not in .scanning state")
        #expect(!mock.capturePhotoCalled)
    }

    @Test @MainActor func detectionRequiresSufficientDuration() {
        let mock = MockCameraService()
        // Use a long duration so the timer never expires in this test
        let vm = ScannerViewModel(cameraService: mock, requiredDetectionDuration: 999)
        vm.hasPermission = true
        vm.startScanning()

        let barcode = DetectedBarcode(data: "12345", format: .qr, boundingBox: .zero)
        vm.processBarcodeDetections([barcode])
        vm.processBarcodeDetections([barcode])

        #expect(vm.state == .scanning, "Should not transition to .detected before requiredDetectionDuration elapses")
        #expect(!mock.capturePhotoCalled)
    }

    @Test @MainActor func previewLayerReturnsSameInstanceThroughViewModel() {
        let mock = MockCameraService()
        let vm = ScannerViewModel(cameraService: mock)

        let layer1 = vm.previewLayer
        let layer2 = vm.previewLayer
        #expect(layer1 === layer2, "Repeated previewLayer access must return the same instance")
    }

    @Test @MainActor func setupFailureSetsErrorState() async {
        let mock = MockCameraService()
        mock.setupSessionError = CameraError.cameraUnavailable
        let vm = ScannerViewModel(cameraService: mock)
        vm.hasPermission = true

        do {
            try await mock.setupSession()
        } catch {
            vm.handleError(error as! CameraError)
        }

        #expect(mock.setupSessionCalled)
        #expect(vm.state == .error("Camera is not available on this device"))
    }
}

// MARK: - AudioDetectionService Tests

@Suite("AudioDetectionService")
struct AudioDetectionServiceTests {
    @Test func initialStateIsNotListening() {
        let service = AudioDetectionService()
        #expect(service.isListening == false)
        #expect(service.onSpikeDetected == nil)
    }

    @Test func stopWhenNotListeningDoesNotCrash() {
        let service = AudioDetectionService()
        service.stopListening()
        #expect(service.isListening == false)
    }
}

// MARK: - TapDetectionService Tests

@Suite("TapDetectionService")
struct TapDetectionServiceTests {
    @Test func initialStateIsNotDetecting() {
        let service = TapDetectionService()
        #expect(service.isDetecting == false)
        #expect(service.onTapDetected == nil)
    }

    @Test func stopWhenNotDetectingDoesNotCrash() {
        let service = TapDetectionService()
        service.stopDetecting()
        #expect(service.isDetecting == false)
    }
}

// MARK: - GroupBarcodeViewModel BeepTap Mode Tests

@Suite("GroupBarcodeViewModel BeepTap Mode")
struct GroupBarcodeViewModelBeepTapTests {

    private func makeGroup(cardCount: Int) -> CardGroup {
        let group = CardGroup(name: "Test Group")
        for i in 0..<cardCount {
            let card = Card(
                name: "Card \(i)",
                barcodeData: "data\(i)",
                barcodeFormat: .qr,
                dateAdded: Date().addingTimeInterval(Double(i))
            )
            card.group = group
            group.cards.append(card)
        }
        return group
    }

    // MARK: - Ghost Page Helpers

    @Test @MainActor func usesGhostPagesWhenMultipleCards() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)
        #expect(vm.usesGhostPages == true)
        #expect(vm.loopingPageCount == 5) // 3 + 2 ghost
        #expect(vm.initialPage == 1)
    }

    @Test @MainActor func noGhostPagesForSingleCard() {
        let group = makeGroup(cardCount: 1)
        let vm = GroupBarcodeViewModel(group: group)
        #expect(vm.usesGhostPages == false)
        #expect(vm.loopingPageCount == 1)
        #expect(vm.initialPage == 0)
    }

    @Test @MainActor func noGhostPagesForEmptyGroup() {
        let group = makeGroup(cardCount: 0)
        let vm = GroupBarcodeViewModel(group: group)
        #expect(vm.usesGhostPages == false)
        #expect(vm.loopingPageCount == 0)
        #expect(vm.initialPage == 0)
    }

    @Test @MainActor func realCardIndexMapsCorrectly() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)

        // Ghost page 0 → last card (index 2)
        #expect(vm.realCardIndex(for: 0) == 2)
        // Real pages 1..3 → card indices 0..2
        #expect(vm.realCardIndex(for: 1) == 0)
        #expect(vm.realCardIndex(for: 2) == 1)
        #expect(vm.realCardIndex(for: 3) == 2)
        // Ghost page 4 → first card (index 0)
        #expect(vm.realCardIndex(for: 4) == 0)
    }

    @Test @MainActor func cardForPageReturnsCorrectCard() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)

        #expect(vm.cardForPage(1)?.name == "Card 0")
        #expect(vm.cardForPage(2)?.name == "Card 1")
        #expect(vm.cardForPage(3)?.name == "Card 2")
        // Ghost pages
        #expect(vm.cardForPage(0)?.name == "Card 2")
        #expect(vm.cardForPage(4)?.name == "Card 0")
    }

    @Test @MainActor func cardForPageReturnsNilForEmptyGroup() {
        let group = makeGroup(cardCount: 0)
        let vm = GroupBarcodeViewModel(group: group)
        #expect(vm.cardForPage(0) == nil)
    }

    @Test @MainActor func displayCounterShowsCorrectValues() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)

        #expect(vm.displayCounter(for: 1) == "1 of 3")
        #expect(vm.displayCounter(for: 2) == "2 of 3")
        #expect(vm.displayCounter(for: 3) == "3 of 3")
    }

    @Test @MainActor func handlePageChangeSnapsBackFromGhostStart() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)

        // Page 0 is ghost-last → snap to page 3 (real last)
        #expect(vm.handlePageChange(0) == 3)
    }

    @Test @MainActor func handlePageChangeSnapsBackFromGhostEnd() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)

        // Page 4 is ghost-first → snap to page 1 (real first)
        #expect(vm.handlePageChange(4) == 1)
    }

    @Test @MainActor func handlePageChangeReturnsNilForRealPages() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)

        #expect(vm.handlePageChange(1) == nil)
        #expect(vm.handlePageChange(2) == nil)
        #expect(vm.handlePageChange(3) == nil)
    }

    @Test @MainActor func handlePageChangeReturnsNilWithoutGhostPages() {
        let group = makeGroup(cardCount: 1)
        let vm = GroupBarcodeViewModel(group: group)

        #expect(vm.handlePageChange(0) == nil)
    }

    // MARK: - Auto-Advance

    @Test @MainActor func nextPageWrapsAround() {
        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(group: group)

        #expect(vm.nextPage(from: 1) == 2)
        #expect(vm.nextPage(from: 2) == 3)
        #expect(vm.nextPage(from: 3) == 1) // loops back
    }

    @Test @MainActor func nextPageSingleCardStaysSame() {
        let group = makeGroup(cardCount: 1)
        let vm = GroupBarcodeViewModel(group: group)

        #expect(vm.nextPage(from: 0) == 0)
    }

    // MARK: - Beep/Tap Mode Enable/Disable

    @Test @MainActor func enableBeepTapModeStartsBothServices() async {
        let mockAudio = MockAudioDetectionService()
        let mockTap = MockTapDetectionService()
        MockAudioDetectionService.permissionResult = true

        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        await vm.enableBeepTapMode { }

        #expect(vm.isBeepTapModeEnabled == true)
        #expect(vm.isDetectionActive == true)
        #expect(mockAudio.startListeningCalled == true)
        #expect(mockTap.startDetectingCalled == true)
    }

    @Test @MainActor func enableBeepTapModePermissionDenied() async {
        let mockAudio = MockAudioDetectionService()
        let mockTap = MockTapDetectionService()
        MockAudioDetectionService.permissionResult = false

        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        await vm.enableBeepTapMode { }

        #expect(vm.isBeepTapModeEnabled == false)
        #expect(vm.microphonePermissionDenied == true)
        #expect(mockAudio.startListeningCalled == false)
        #expect(mockTap.startDetectingCalled == false)
    }

    @Test @MainActor func disableBeepTapModeStopsBothServices() async {
        let mockAudio = MockAudioDetectionService()
        let mockTap = MockTapDetectionService()
        MockAudioDetectionService.permissionResult = true

        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        await vm.enableBeepTapMode { }
        vm.disableBeepTapMode()

        #expect(vm.isBeepTapModeEnabled == false)
        #expect(vm.isDetectionActive == false)
        #expect(mockAudio.stopListeningCalled == true)
        #expect(mockTap.stopDetectingCalled == true)
    }

    // MARK: - Detection Triggers Advance

    @Test @MainActor func audioSpikeTriggersAdvance() async {
        let mockAudio = MockAudioDetectionService()
        let mockTap = MockTapDetectionService()
        MockAudioDetectionService.permissionResult = true

        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        var currentPage = 1
        await vm.enableBeepTapMode {
            currentPage = vm.nextPage(from: currentPage)
        }

        mockAudio.simulateSpike()
        #expect(currentPage == 2)

        mockAudio.simulateSpike()
        #expect(currentPage == 3)

        mockAudio.simulateSpike()
        #expect(currentPage == 1) // looped
    }

    @Test @MainActor func tapDetectionTriggersAdvance() async {
        let mockAudio = MockAudioDetectionService()
        let mockTap = MockTapDetectionService()
        MockAudioDetectionService.permissionResult = true

        let group = makeGroup(cardCount: 2)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        var currentPage = 1
        await vm.enableBeepTapMode {
            currentPage = vm.nextPage(from: currentPage)
        }

        mockTap.simulateTap()
        #expect(currentPage == 2)

        mockTap.simulateTap()
        #expect(currentPage == 1) // looped
    }

    // MARK: - Cleanup

    @Test @MainActor func stopAllDetectionCleansUp() async {
        let mockAudio = MockAudioDetectionService()
        let mockTap = MockTapDetectionService()
        MockAudioDetectionService.permissionResult = true

        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        await vm.enableBeepTapMode { }
        vm.stopAllDetection()

        #expect(vm.isDetectionActive == false)
        #expect(mockAudio.stopListeningCalled == true)
        #expect(mockTap.stopDetectingCalled == true)
    }

    @Test @MainActor func stopAllDetectionNoopWhenNotActive() {
        let mockAudio = MockAudioDetectionService()
        let mockTap = MockTapDetectionService()

        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        vm.stopAllDetection()

        #expect(mockAudio.stopListeningCalled == false)
        #expect(mockTap.stopDetectingCalled == false)
    }

    // MARK: - Audio Failure Degraded Mode

    @Test @MainActor func audioFailureStillAllowsTapDetection() async {
        let mockAudio = MockAudioDetectionService()
        mockAudio.startListeningError = AudioDetectionError.audioEngineSetupFailed
        let mockTap = MockTapDetectionService()
        MockAudioDetectionService.permissionResult = true

        let group = makeGroup(cardCount: 3)
        let vm = GroupBarcodeViewModel(
            group: group,
            audioDetectionService: mockAudio,
            tapDetectionService: mockTap
        )

        var currentPage = 1
        await vm.enableBeepTapMode {
            currentPage = vm.nextPage(from: currentPage)
        }

        #expect(vm.isBeepTapModeEnabled == true)
        #expect(mockTap.startDetectingCalled == true)

        mockTap.simulateTap()
        #expect(currentPage == 2)
    }
}
