//
//  CameraService.swift
//  Yeetcard
//

import AVFoundation
import UIKit

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didCapturePhoto image: UIImage)
    func cameraService(_ service: CameraService, didOutputSampleBuffer sampleBuffer: CMSampleBuffer)
    func cameraService(_ service: CameraService, didFailWithError error: CameraError)
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

final class CameraService: NSObject {
    weak var delegate: CameraServiceDelegate?

    private let captureSession = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?

    private let sessionQueue = DispatchQueue(label: "com.yeetcard.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.yeetcard.camera.video")

    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

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

    func setupSession() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraUnavailable
        }

        currentDevice = device

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            let photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                self.photoOutput = photoOutput
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }

            captureSession.commitConfiguration()
        } catch {
            captureSession.commitConfiguration()
            throw CameraError.setupFailed
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
