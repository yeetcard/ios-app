//
//  CameraService.swift
//  Yeetcard
//

import AVFoundation
import UIKit

protocol CameraServiceProtocol: AnyObject {
    var delegate: (any CameraServiceDelegate)? { get set }
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    var isFlashAvailable: Bool { get }
    var isFlashOn: Bool { get set }
    func setupSession() async throws
    func startSession()
    func stopSession()
    func capturePhoto()
    func toggleFlash()
}

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: any CameraServiceProtocol, didCapturePhoto image: UIImage)
    func cameraService(_ service: any CameraServiceProtocol, didOutputSampleBuffer sampleBuffer: CMSampleBuffer)
    func cameraService(_ service: any CameraServiceProtocol, didFailWithError error: CameraError)
}

enum CameraError: Error, LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case setupFailed
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera access was denied. Please enable it in Settings."
        case .setupFailed:
            return "Failed to set up the camera"
        case .captureFailed:
            return "Failed to capture photo"
        }
    }
}

final class CameraService: NSObject, CameraServiceProtocol {
    weak var delegate: (any CameraServiceDelegate)?

    private let captureSession = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?

    private let sessionQueue = DispatchQueue(label: "com.yeetcard.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.yeetcard.camera.video")

    private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    var isFlashAvailable: Bool {
        currentDevice?.hasTorch ?? false
    }

    var isFlashOn: Bool = false

    static func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func setupSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.setupFailed)
                    return
                }

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    continuation.resume(throwing: CameraError.cameraUnavailable)
                    return
                }

                self.currentDevice = device

                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = .photo

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.captureSession.canAddInput(input) {
                        self.captureSession.addInput(input)
                    }

                    let photoOutput = AVCapturePhotoOutput()
                    if self.captureSession.canAddOutput(photoOutput) {
                        self.captureSession.addOutput(photoOutput)
                        self.photoOutput = photoOutput
                    }

                    let videoOutput = AVCaptureVideoDataOutput()
                    videoOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
                    videoOutput.alwaysDiscardsLateVideoFrames = true
                    if self.captureSession.canAddOutput(videoOutput) {
                        self.captureSession.addOutput(videoOutput)
                        self.videoOutput = videoOutput
                    }

                    self.captureSession.commitConfiguration()
                    continuation.resume()
                } catch {
                    self.captureSession.commitConfiguration()
                    continuation.resume(throwing: CameraError.setupFailed)
                }
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            delegate?.cameraService(self, didFailWithError: .captureFailed)
            return
        }

        let settings = AVCapturePhotoSettings()
        if isFlashAvailable && isFlashOn {
            settings.flashMode = .on
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleFlash() {
        guard isFlashAvailable, let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Silently fail
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraService(self, didOutputSampleBuffer: sampleBuffer)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            DispatchQueue.main.async {
                self.delegate?.cameraService(self, didFailWithError: .captureFailed)
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.delegate?.cameraService(self, didFailWithError: .captureFailed)
            }
            return
        }

        DispatchQueue.main.async {
            self.delegate?.cameraService(self, didCapturePhoto: image)
        }
    }
}
