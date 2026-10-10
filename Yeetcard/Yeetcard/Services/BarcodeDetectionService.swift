//
//  BarcodeDetectionService.swift
//  Yeetcard
//

import Vision
import AVFoundation
import UIKit

nonisolated struct DetectedBarcode {
    let data: String
    let format: BarcodeFormat
    let boundingBox: CGRect
}

protocol BarcodeDetectionServiceProtocol {
    func detectBarcodes(in image: UIImage) async -> [DetectedBarcode]
}

// Nonisolated so the scanner can run detection on the camera's video queue and photo import can
// run it off the main actor.
nonisolated final class BarcodeDetectionService: BarcodeDetectionServiceProtocol, Sendable {
    // Vision only reports the symbologies it is asked for, so anything missing here is never
    // found, however clearly it shows up in the frame (library cards, for example, are Codabar).
    static let formatsBySymbology: [VNBarcodeSymbology: BarcodeFormat] = [
        .qr: .qr,
        .microQR: .microQR,
        .code128: .code128,
        .code39: .code39,
        .code93: .code93,
        .ean13: .ean13,
        .ean8: .ean8,
        .upce: .upcE,
        .codabar: .codabar,
        .i2of5: .itf,
        .itf14: .itf,
        .gs1DataBar: .gs1DataBar,
        .gs1DataBarExpanded: .gs1DataBar,
        .gs1DataBarLimited: .gs1DataBar,
        .msiPlessey: .msiPlessey,
        .pdf417: .pdf417,
        .microPDF417: .microPDF417,
        .aztec: .aztec,
        .dataMatrix: .dataMatrix
    ]

    func detectBarcodes(in sampleBuffer: CMSampleBuffer) -> [DetectedBarcode] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return []
        }

        return detectBarcodes(in: pixelBuffer)
    }

    func detectBarcodes(in pixelBuffer: CVPixelBuffer) -> [DetectedBarcode] {
        perform(VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]))
    }

    @concurrent
    func detectBarcodes(in image: UIImage) async -> [DetectedBarcode] {
        guard let cgImage = image.cgImage else { return [] }

        return perform(VNImageRequestHandler(cgImage: cgImage, options: [:]))
    }

    private func perform(_ handler: VNImageRequestHandler) -> [DetectedBarcode] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = Array(Self.formatsBySymbology.keys)

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
            guard let payloadString = observation.payloadStringValue,
                  let format = Self.formatsBySymbology[observation.symbology] else { return nil }

            return DetectedBarcode(
                data: payloadString,
                format: format,
                boundingBox: observation.boundingBox
            )
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
