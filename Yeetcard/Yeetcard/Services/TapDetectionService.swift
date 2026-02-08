//
//  TapDetectionService.swift
//  Yeetcard
//

import CoreMotion

struct TapDebugInfo {
    var magnitude: Double = 0.0
    var previousMagnitude: Double = 0.0
    var spikeThreshold: Double = 0.0
    var quietThreshold: Double = 0.0
    var debounceInterval: TimeInterval = 0.0
    var timeSinceLastTrigger: TimeInterval = .infinity
    var triggered: Bool = false
}

protocol TapDetectionServiceProtocol: AnyObject {
    var isDetecting: Bool { get }
    var onTapDetected: (() -> Void)? { get set }
    var onDebugUpdate: ((TapDebugInfo) -> Void)? { get set }
    func startDetecting()
    func stopDetecting()
}

final class TapDetectionService: TapDetectionServiceProtocol {
    var isDetecting: Bool = false
    var onTapDetected: (() -> Void)?
    var onDebugUpdate: ((TapDebugInfo) -> Void)?

    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var lastTriggerTime: Date = .distantPast
    private var previousMagnitude: Double = 0.0
    private var lastDebugTime: Date = .distantPast

    private let spikeThreshold: Double = 1.4
    private let quietThreshold: Double = 1.15
    private let debounceInterval: TimeInterval = 0.8

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

        var triggered = false
        if magnitude > spikeThreshold && previousMagnitude < quietThreshold {
            let now = Date()
            if now.timeIntervalSince(lastTriggerTime) >= debounceInterval {
                lastTriggerTime = now
                triggered = true
                let callback = onTapDetected
                DispatchQueue.main.async {
                    callback?()
                }
            }
        }

        let now = Date()
        if triggered || now.timeIntervalSince(lastDebugTime) >= 0.1 {
            lastDebugTime = now
            let info = TapDebugInfo(
                magnitude: magnitude,
                previousMagnitude: previousMagnitude,
                spikeThreshold: spikeThreshold,
                quietThreshold: quietThreshold,
                debounceInterval: debounceInterval,
                timeSinceLastTrigger: now.timeIntervalSince(lastTriggerTime),
                triggered: triggered
            )
            let debugCallback = onDebugUpdate
            DispatchQueue.main.async {
                debugCallback?(info)
            }
        }

        previousMagnitude = magnitude
    }
}
