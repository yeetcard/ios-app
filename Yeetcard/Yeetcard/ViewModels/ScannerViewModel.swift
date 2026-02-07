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

    private let cameraService: any CameraServiceProtocol
    private let barcodeDetectionService = BarcodeDetectionService()

    private var lastDetectedBarcode: DetectedBarcode?
    private var detectionStartTime: Date?
    let requiredDetectionDuration: TimeInterval

    var state: ScannerState = .idle
    var hasPermission: Bool = false
    var isFlashOn: Bool = false

    var previewLayer: AVCaptureVideoPreviewLayer {
        cameraService.previewLayer
    }

    var isFlashAvailable: Bool {
        cameraService.isFlashAvailable
    }

    init(cameraService: any CameraServiceProtocol = CameraService(),
         requiredDetectionDuration: TimeInterval = 1.0) {
        self.cameraService = cameraService
        self.requiredDetectionDuration = requiredDetectionDuration
        self.cameraService.delegate = self
    }

    func checkPermission() async {
        hasPermission = await CameraService.checkPermission()

        if hasPermission {
            do {
                try await cameraService.setupSession()
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

    func processBarcodeDetections(_ detectedBarcodes: [DetectedBarcode]) {
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

    func handlePhotoCaptured(_ image: UIImage) {
        if case .detected(let barcode) = state {
            state = .captured(image, barcode)
        }
    }

    func handleError(_ error: CameraError) {
        state = .error(error.errorDescription ?? "Camera error")
    }
}

extension ScannerViewModel: CameraServiceDelegate {
    nonisolated func cameraService(_ service: any CameraServiceProtocol, didCapturePhoto image: UIImage) {
        Task { @MainActor in
            handlePhotoCaptured(image)
        }
    }

    nonisolated func cameraService(_ service: any CameraServiceProtocol, didOutputSampleBuffer sampleBuffer: CMSampleBuffer) {
        Task {
            let detectedBarcodes = await barcodeDetectionService.detectBarcodes(in: sampleBuffer)

            await MainActor.run {
                processBarcodeDetections(detectedBarcodes)
            }
        }
    }

    nonisolated func cameraService(_ service: any CameraServiceProtocol, didFailWithError error: CameraError) {
        Task { @MainActor in
            handleError(error)
        }
    }
}
