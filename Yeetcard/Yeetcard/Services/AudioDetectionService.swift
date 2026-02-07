//
//  AudioDetectionService.swift
//  Yeetcard
//

import AVFoundation

enum AudioDetectionError: Error, LocalizedError {
    case microphonePermissionDenied
    case audioEngineSetupFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access was denied. Please enable it in Settings."
        case .audioEngineSetupFailed:
            return "Failed to set up audio detection."
        }
    }
}

protocol AudioDetectionServiceProtocol: AnyObject {
    var isListening: Bool { get }
    var onSpikeDetected: (() -> Void)? { get set }
    func startListening() throws
    func stopListening()
    static func checkPermission() async -> Bool
}

final class AudioDetectionService: AudioDetectionServiceProtocol {
    var isListening: Bool = false
    var onSpikeDetected: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var previousRMS: Float = 0.0
    private var lastTriggerTime: Date = .distantPast

    private let spikeThreshold: Float = 0.15
    private let quietThreshold: Float = 0.05
    private let debounceInterval: TimeInterval = 1.0

    static func checkPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func startListening() throws {
        guard !isListening else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    func stopListening() {
        guard isListening else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isListening = false
        previousRMS = 0.0
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))

        if rms > spikeThreshold && previousRMS < quietThreshold {
            let now = Date()
            if now.timeIntervalSince(lastTriggerTime) >= debounceInterval {
                lastTriggerTime = now
                let callback = onSpikeDetected
                DispatchQueue.main.async {
                    callback?()
                }
            }
        }
        previousRMS = rms
    }
}
