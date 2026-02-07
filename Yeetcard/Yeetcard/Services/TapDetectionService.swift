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

    private let accelerationThreshold: Double = 2.5
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
    }

    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = data.acceleration
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )

        if magnitude > accelerationThreshold {
            let now = Date()
            if now.timeIntervalSince(lastTriggerTime) >= debounceInterval {
                lastTriggerTime = now
                let callback = onTapDetected
                DispatchQueue.main.async {
                    callback?()
                }
            }
        }
    }
}
