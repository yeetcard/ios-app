//
//  TapDetectionService.swift
//  Yeetcard
//

import CoreMotion

protocol TapDetectionServiceProtocol: AnyObject {
    var isDetecting: Bool { get }
    var onTapDetected: (() -> Void)? { get set }
    func startDetecting()
    func stopDetecting()
}

final class TapDetectionService: TapDetectionServiceProtocol {
    var isDetecting: Bool = false
    var onTapDetected: (() -> Void)?

    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var lastTriggerTime: Date = .distantPast
    private var previousMagnitude: Double = 0.0

    private let spikeThreshold: Double = 1.8
    private let quietThreshold: Double = 1.2
    private let debounceInterval: TimeInterval = 1.0

    init() {
        motionQueue.name = "com.yeetcard.tapdetection"
        motionQueue.maxConcurrentOperationCount = 1
    }

    func startDetecting() {
        guard !isDetecting, motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = 0.01
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.processAccelerometerData(data)
        }
        isDetecting = true
    }

    func stopDetecting() {
        guard isDetecting else { return }
        motionManager.stopAccelerometerUpdates()
        isDetecting = false
        previousMagnitude = 0.0
    }

    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = data.acceleration
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )

        if magnitude > spikeThreshold && previousMagnitude < quietThreshold {
            let now = Date()
            if now.timeIntervalSince(lastTriggerTime) >= debounceInterval {
                lastTriggerTime = now
                let callback = onTapDetected
                DispatchQueue.main.async {
                    callback?()
                }
            }
        }
        previousMagnitude = magnitude
    }
}
