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
        case .code39:
            ciImage = generateCode39(data: data)
        case .ean13:
            ciImage = generateEAN13(data: data)
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

    // MARK: - Code 39

    // Each character is 9 elements: alternating bar/space widths (1=narrow, 3=wide)
    private static let code39Patterns: [Character: [Int]] = [
        "0": [1,1,1,3,3,1,3,1,1], "1": [3,1,1,3,1,1,1,1,3],
        "2": [1,1,3,3,1,1,1,1,3], "3": [3,1,3,3,1,1,1,1,1],
        "4": [1,1,1,3,3,1,1,1,3], "5": [3,1,1,3,3,1,1,1,1],
        "6": [1,1,3,3,3,1,1,1,1], "7": [1,1,1,3,1,1,3,1,3],
        "8": [3,1,1,3,1,1,3,1,1], "9": [1,1,3,3,1,1,3,1,1],
        "A": [3,1,1,1,1,3,1,1,3], "B": [1,1,3,1,1,3,1,1,3],
        "C": [3,1,3,1,1,3,1,1,1], "D": [1,1,1,1,3,3,1,1,3],
        "E": [3,1,1,1,3,3,1,1,1], "F": [1,1,3,1,3,3,1,1,1],
        "G": [1,1,1,1,1,3,3,1,3], "H": [3,1,1,1,1,3,3,1,1],
        "I": [1,1,3,1,1,3,3,1,1], "J": [1,1,1,1,3,3,3,1,1],
        "K": [3,1,1,1,1,1,1,3,3], "L": [1,1,3,1,1,1,1,3,3],
        "M": [3,1,3,1,1,1,1,3,1], "N": [1,1,1,1,3,1,1,3,3],
        "O": [3,1,1,1,3,1,1,3,1], "P": [1,1,3,1,3,1,1,3,1],
        "Q": [1,1,1,1,1,1,3,3,3], "R": [3,1,1,1,1,1,3,3,1],
        "S": [1,1,3,1,1,1,3,3,1], "T": [1,1,1,1,3,1,3,3,1],
        "U": [3,3,1,1,1,1,1,1,3], "V": [1,3,3,1,1,1,1,1,3],
        "W": [3,3,3,1,1,1,1,1,1], "X": [1,3,1,1,3,1,1,1,3],
        "Y": [3,3,1,1,3,1,1,1,1], "Z": [1,3,3,1,3,1,1,1,1],
        "-": [1,3,1,1,1,1,3,1,3], ".": [3,3,1,1,1,1,3,1,1],
        " ": [1,3,3,1,1,1,3,1,1], "$": [1,3,1,3,1,3,1,1,1],
        "/": [1,3,1,3,1,1,1,3,1], "+": [1,3,1,1,1,3,1,3,1],
        "%": [1,1,1,3,1,3,1,3,1], "*": [1,3,1,1,3,1,3,1,1],
    ]

    private func generateCode39(data: String) -> CIImage? {
        let chars = Array("*" + data.uppercased() + "*")
        for ch in chars {
            guard Self.code39Patterns[ch] != nil else { return nil }
        }

        var modules: [Bool] = []
        let quietZone = 10

        modules.append(contentsOf: repeatElement(false, count: quietZone))
        for (i, ch) in chars.enumerated() {
            let pattern = Self.code39Patterns[ch]!
            for (j, width) in pattern.enumerated() {
                let isBar = j % 2 == 0
                modules.append(contentsOf: repeatElement(isBar, count: width))
            }
            if i < chars.count - 1 {
                modules.append(false) // inter-character gap
            }
        }
        modules.append(contentsOf: repeatElement(false, count: quietZone))

        return renderModulesToCIImage(modules: modules, height: 80)
    }

    // MARK: - EAN-13

    // Parity pattern for left digits based on first digit (0=L, 1=G)
    private static let ean13Parity: [[Int]] = [
        [0,0,0,0,0,0], [0,0,1,0,1,1], [0,0,1,1,0,1], [0,0,1,1,1,0],
        [0,1,0,0,1,1], [0,1,1,0,0,1], [0,1,1,1,0,0], [0,1,0,1,0,1],
        [0,1,0,1,1,0], [0,1,1,0,1,0],
    ]

    // L-code encoding for digits 0-9 (odd parity)
    private static let lCode: [[Int]] = [
        [0,0,0,1,1,0,1], [0,0,1,1,0,0,1], [0,0,1,0,0,1,1], [0,1,1,1,1,0,1],
        [0,1,0,0,0,1,1], [0,1,1,0,0,0,1], [0,1,0,1,1,1,1], [0,1,1,1,0,1,1],
        [0,1,1,0,1,1,1], [0,0,0,1,0,1,1],
    ]

    // G-code encoding for digits 0-9 (even parity)
    private static let gCode: [[Int]] = [
        [0,1,0,0,1,1,1], [0,1,1,0,0,1,1], [0,0,1,1,0,1,1], [0,1,0,0,0,0,1],
        [0,0,1,1,1,0,1], [0,1,1,1,0,0,1], [0,0,0,0,1,0,1], [0,0,1,0,0,0,1],
        [0,0,0,1,0,0,1], [0,0,1,0,1,1,1],
    ]

    // R-code encoding for digits 0-9
    private static let rCode: [[Int]] = [
        [1,1,1,0,0,1,0], [1,1,0,0,1,1,0], [1,1,0,1,1,0,0], [1,0,0,0,0,1,0],
        [1,0,1,1,1,0,0], [1,0,0,1,1,1,0], [1,0,1,0,0,0,0], [1,0,0,0,1,0,0],
        [1,0,0,1,0,0,0], [1,1,1,0,1,0,0],
    ]

    private func generateEAN13(data: String) -> CIImage? {
        guard data.count == 13, data.allSatisfy({ $0.isNumber }) else { return nil }

        let digits = data.compactMap { $0.wholeNumberValue }
        guard digits.count == 13 else { return nil }

        let parity = Self.ean13Parity[digits[0]]
        let leftDigits = Array(digits[1...6])
        let rightDigits = Array(digits[7...12])

        var modules: [Bool] = []

        // Left quiet zone
        modules.append(contentsOf: repeatElement(false, count: 11))

        // Start guard: 101
        modules.append(contentsOf: [true, false, true])

        // Left 6 digits
        for (i, digit) in leftDigits.enumerated() {
            let encoding = parity[i] == 0 ? Self.lCode[digit] : Self.gCode[digit]
            modules.append(contentsOf: encoding.map { $0 == 1 })
        }

        // Center guard: 01010
        modules.append(contentsOf: [false, true, false, true, false])

        // Right 6 digits
        for digit in rightDigits {
            let encoding = Self.rCode[digit]
            modules.append(contentsOf: encoding.map { $0 == 1 })
        }

        // End guard: 101
        modules.append(contentsOf: [true, false, true])

        // Right quiet zone
        modules.append(contentsOf: repeatElement(false, count: 7))

        return renderModulesToCIImage(modules: modules, height: 80)
    }

    // MARK: - Module Rendering

    private func renderModulesToCIImage(modules: [Bool], height: Int) -> CIImage? {
        let width = modules.count
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        ctx.setFillColor(gray: 0.0, alpha: 1.0)
        for (x, isBar) in modules.enumerated() {
            if isBar {
                ctx.fill(CGRect(x: x, y: 0, width: 1, height: height))
            }
        }

        guard let cgImage = ctx.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
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
