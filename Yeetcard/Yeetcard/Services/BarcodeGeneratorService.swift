//
//  BarcodeGeneratorService.swift
//  Yeetcard
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

protocol BarcodeGeneratorServiceProtocol {
    func generateBarcode(data: String, format: BarcodeFormat, size: CGSize) -> UIImage?
    func validateBarcodeData(_ data: String, for format: BarcodeFormat) -> Bool
}

extension BarcodeGeneratorServiceProtocol {
    func generateBarcode(data: String, format: BarcodeFormat) -> UIImage? {
        generateBarcode(data: data, format: format, size: CGSize(width: 300, height: 300))
    }
}

final class BarcodeGeneratorService: BarcodeGeneratorServiceProtocol {
    static let shared = BarcodeGeneratorService()

    private let context = CIContext()

    private init() {}

    func generateBarcode(data: String, format: BarcodeFormat, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        guard format.canGenerate else { return nil }

        var ciImage: CIImage?

        switch format {
        case .qr:
            ciImage = generateQRCode(data: data)
        case .code128:
            ciImage = generateCode128(data: data)
        case .pdf417:
            ciImage = generatePDF417(data: data)
        case .aztec:
            ciImage = generateAztec(data: data)
        default:
            return nil
        }

        guard let image = ciImage else { return nil }

        return scaleImage(image, to: size)
    }

    private func generateQRCode(data: String) -> CIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(data.utf8)
        filter.correctionLevel = "M"
        return filter.outputImage
    }

    private func generateCode128(data: String) -> CIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(data.utf8)
        filter.quietSpace = 10
        return filter.outputImage
    }

    private func generatePDF417(data: String) -> CIImage? {
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = Data(data.utf8)
        return filter.outputImage
    }

    private func generateAztec(data: String) -> CIImage? {
        let filter = CIFilter.aztecCodeGenerator()
        filter.message = Data(data.utf8)
        filter.correctionLevel = 23
        return filter.outputImage
    }

    private func scaleImage(_ ciImage: CIImage, to size: CGSize) -> UIImage? {
        let extent = ciImage.extent

        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let scale = min(scaleX, scaleY)

        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    func validateBarcodeData(_ data: String, for format: BarcodeFormat) -> Bool {
        guard !data.isEmpty else { return false }

        switch format {
        case .ean13:
            return data.count == 13 && data.allSatisfy { $0.isNumber }
        case .ean8:
            return data.count == 8 && data.allSatisfy { $0.isNumber }
        case .upcA:
            return data.count == 12 && data.allSatisfy { $0.isNumber }
        case .upcE:
            return data.count == 8 && data.allSatisfy { $0.isNumber }
        case .qr, .code128, .code39, .pdf417, .aztec, .dataMatrix:
            return true
        }
    }
}
