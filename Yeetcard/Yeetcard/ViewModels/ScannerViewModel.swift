//
//  ScannerViewModel.swift
//  Yeetcard
//

import SwiftUI
import AVFoundation

@MainActor
@Observable
final class ScannerViewModel {
    enum ScannerState: Equatable {
        case idle
        case scanning
        case detected(DetectedBarcode)
        case captured(UIImage, DetectedBarcode)
        case error(String)

        static func == (lhs: ScannerState, rhs: ScannerState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning):
                return true
            case (.detected(let a), .detected(let b)):
                return a.data == b.data && a.format == b.format
            case (.captured(_, let a), .captured(_, let b)):
                return a.data == b.data && a.format == b.format
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private let cameraService = CameraService()
    private let barcodeDetectionService = BarcodeDetectionService()

    private var lastDetectedBarcode: DetectedBarcode?
    private var detectionStartTime: Date?
    private let requiredDetectionDuration: TimeInterval = 1.0

    var state: ScannerState = .idle
    var hasPermission: Bool = false
    var isFlashOn: Bool = false

    var previewLayer: AVCaptureVideoPreviewLayer {
        cameraService.previewLayer
    }

    var isFlashAvailable: Bool {
        cameraService.isFlashAvailable
    }

    init() {
        cameraService.delegate = self
    }

    func checkPermission() async {
        hasPermission = await CameraService.checkPermission()

        if hasPermission {
            do {
                try cameraService.setupSession()
            } catch {
                state = .error((error as? CameraError)?.errorDescription ?? "Camera setup failed")
            }
        }
    }

    func startScanning() {
        guard hasPermission else { return }
        state = .scanning
        cameraService.startSession()
    }

    func stopScanning() {
        cameraService.stopSession()
        state = .idle
    }

    func toggleFlash() {
        cameraService.toggleFlash()
        isFlashOn = cameraService.isFlashOn
    }

    func capturePhoto() {
        cameraService.capturePhoto()
    }

    func reset() {
        lastDetectedBarcode = nil
        detectionStartTime = nil
        state = .scanning
    }
}

extension ScannerViewModel: CameraServiceDelegate {
    nonisolated func cameraService(_ service: CameraService, didCapturePhoto image: UIImage) {
        Task { @MainActor in
            if case .detected(let barcode) = state {
                state = .captured(image, barcode)
            }
        }
    }

    nonisolated func cameraService(_ service: CameraService, didOutputSampleBuffer sampleBuffer: CMSampleBuffer) {
        Task {
            let detectedBarcodes = await barcodeDetectionService.detectBarcodes(in: sampleBuffer)

            await MainActor.run {
                guard case .scanning = state else { return }

                if let barcode = detectedBarcodes.first {
                    if let lastBarcode = lastDetectedBarcode,
                       lastBarcode.data == barcode.data,
                       lastBarcode.format == barcode.format {
                        if let startTime = detectionStartTime,
                           Date().timeIntervalSince(startTime) >= requiredDetectionDuration {
                            state = .detected(barcode)
                            cameraService.capturePhoto()
                        }
                    } else {
                        lastDetectedBarcode = barcode
                        detectionStartTime = Date()
                    }
                } else {
                    lastDetectedBarcode = nil
                    detectionStartTime = nil
                }
            }
        }
    }

    nonisolated func cameraService(_ service: CameraService, didFailWithError error: CameraError) {
        Task { @MainActor in
            state = .error(error.errorDescription ?? "Camera error")
        }
    }
}
