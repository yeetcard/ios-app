//
//  BarcodeDetectionService.swift
//  Yeetcard
//

import Vision
import AVFoundation
import UIKit

struct DetectedBarcode {
    let data: String
    let format: BarcodeFormat
    let boundingBox: CGRect
}

final class BarcodeDetectionService {
    private let supportedSymbologies: [VNBarcodeSymbology] = [
        .qr,
        .code128,
        .code39,
        .ean13,
        .ean8,
        .upce,
        .pdf417,
        .aztec,
        .dataMatrix
    ]

    func detectBarcodes(in sampleBuffer: CMSampleBuffer) async -> [DetectedBarcode] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return []
        }

        return await detectBarcodes(in: pixelBuffer)
    }

    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async -> [DetectedBarcode] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = supportedSymbologies

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
            return processResults(request.results)
        } catch {
            return []
        }
    }

    func detectBarcodes(in image: UIImage) async -> [DetectedBarcode] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNDetectBarcodesRequest()
        request.symbologies = supportedSymbologies

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            return processResults(request.results)
        } catch {
            return []
        }
    }

    private func processResults(_ results: [VNBarcodeObservation]?) -> [DetectedBarcode] {
        guard let observations = results else { return [] }

        return observations.compactMap { observation in
            guard let payloadString = observation.payloadStringValue else { return nil }

            let format = mapSymbologyToFormat(observation.symbology)

            return DetectedBarcode(
                data: payloadString,
                format: format,
                boundingBox: observation.boundingBox
            )
        }
    }

    private func mapSymbologyToFormat(_ symbology: VNBarcodeSymbology) -> BarcodeFormat {
        switch symbology {
        case .qr:
            return .qr
        case .code128:
            return .code128
        case .code39:
            return .code39
        case .ean13:
            return .ean13
        case .ean8:
            return .ean8
        case .upce:
            return .upcE
        case .pdf417:
            return .pdf417
        case .aztec:
            return .aztec
        case .dataMatrix:
            return .dataMatrix
        default:
            return .qr
        }
    }

    func extractBarcodeRegion(from image: UIImage, boundingBox: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let flippedBox = CGRect(
            x: boundingBox.origin.x * width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )

        let padding: CGFloat = 20
        let expandedRect = flippedBox.insetBy(dx: -padding, dy: -padding)
        let clampedRect = expandedRect.intersection(CGRect(x: 0, y: 0, width: width, height: height))

        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else { return nil }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
