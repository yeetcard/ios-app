//
//  AuthenticationService.swift
//  Yeetcard
//

import LocalAuthentication

enum BiometricType {
    case none
    case touchID
    case faceID

    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }
}

enum AuthenticationError: Error, LocalizedError {
    case biometricsUnavailable
    case authenticationFailed
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .biometricsUnavailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancelled:
            return "Authentication was cancelled"
        }
    }
}

protocol AuthenticationServiceProtocol {
    var availableBiometricType: BiometricType { get }
    var isBiometricsAvailable: Bool { get }
    func authenticate() async throws
}

final class AuthenticationService: AuthenticationServiceProtocol {
    static let shared = AuthenticationService()

    private init() {}

    var availableBiometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .faceID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    var isBiometricsAvailable: Bool {
        availableBiometricType != .none
    }

    func authenticate() async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue,
                     LAError.biometryNotEnrolled.rawValue:
                    throw AuthenticationError.biometricsUnavailable
                default:
                    throw AuthenticationError.authenticationFailed
                }
            }
            throw AuthenticationError.biometricsUnavailable
        }

        let reason = "Unlock Yeetcard to access your cards"

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)

            if !success {
                throw AuthenticationError.authenticationFailed
            }
        } catch let authError as LAError {
            switch authError.code {
            case .userCancel, .appCancel:
                throw AuthenticationError.userCancelled
            case .biometryNotAvailable, .biometryNotEnrolled:
                throw AuthenticationError.biometricsUnavailable
            default:
                throw AuthenticationError.authenticationFailed
            }
        }
    }
}
