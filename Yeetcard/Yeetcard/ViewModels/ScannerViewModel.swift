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
    nonisolated private let barcodeDetectionService = BarcodeDetectionService()

    private var lastDetectedBarcode: DetectedBarcode?
    private var detectionStartTime: Date?
    private var lastSeenTime: Date?
    let requiredDetectionDuration: TimeInterval
    let dropoutTolerance: TimeInterval

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
         requiredDetectionDuration: TimeInterval = 1.0,
         dropoutTolerance: TimeInterval = 0.5) {
        self.cameraService = cameraService
        self.requiredDetectionDuration = requiredDetectionDuration
        self.dropoutTolerance = dropoutTolerance
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
        lastSeenTime = nil
        state = .scanning
    }

    func processBarcodeDetections(_ detectedBarcodes: [DetectedBarcode], at now: Date = Date()) {
        guard case .scanning = state else { return }

        // Look for the candidate anywhere in the frame: Vision's ordering isn't stable when more
        // than one code is visible.
        if let candidate = lastDetectedBarcode,
           detectedBarcodes.contains(where: { $0.data == candidate.data && $0.format == candidate.format }) {
            lastSeenTime = now
            if let startTime = detectionStartTime,
               now.timeIntervalSince(startTime) >= requiredDetectionDuration {
                state = .detected(candidate)
                cameraService.capturePhoto()
            }
            return
        }

        // Vision misses the odd frame (motion blur, refocusing), so only drop the candidate once
        // it has been out of sight for a while.
        if let lastSeen = lastSeenTime, now.timeIntervalSince(lastSeen) <= dropoutTolerance {
            return
        }

        lastDetectedBarcode = detectedBarcodes.first
        detectionStartTime = detectedBarcodes.isEmpty ? nil : now
        lastSeenTime = detectionStartTime
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
        // Called on the camera's video queue. Detecting synchronously keeps Vision off the main
        // thread and lets the capture output drop frames while we're busy, rather than queueing
        // a task per frame.
        let detectedBarcodes = barcodeDetectionService.detectBarcodes(in: sampleBuffer)

        Task { @MainActor in
            processBarcodeDetections(detectedBarcodes)
        }
    }

    nonisolated func cameraService(_ service: any CameraServiceProtocol, didFailWithError error: CameraError) {
        Task { @MainActor in
            handleError(error)
        }
    }
}
