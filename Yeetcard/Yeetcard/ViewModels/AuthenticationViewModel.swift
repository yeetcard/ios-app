//
//  AuthenticationViewModel.swift
//  Yeetcard
//

import SwiftUI

@MainActor
@Observable
final class AuthenticationViewModel {
    private let authService: any AuthenticationServiceProtocol

    init(authService: any AuthenticationServiceProtocol = AuthenticationService.shared) {
        self.authService = authService
    }

    var isAuthenticated: Bool = false
    var isAuthenticating: Bool = false
    var errorMessage: String?
    var showRetryButton: Bool = false

    var biometricType: BiometricType {
        authService.availableBiometricType
    }

    var isBiometricsAvailable: Bool {
        authService.isBiometricsAvailable
    }

    var promptText: String {
        switch biometricType {
        case .faceID:
            return "Use Face ID to unlock"
        case .touchID:
            return "Use Touch ID to unlock"
        case .none:
            return "Biometrics unavailable"
        }
    }

    var iconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.fill"
        }
    }

    func authenticate() async {
        guard isBiometricsAvailable else {
            isAuthenticated = true
            return
        }

        isAuthenticating = true
        errorMessage = nil
        showRetryButton = false

        do {
            try await authService.authenticate()
            isAuthenticated = true
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
            showRetryButton = true
        } catch {
            errorMessage = "Authentication failed"
            showRetryButton = true
        }

        isAuthenticating = false
    }

    func reset() {
        isAuthenticated = false
        errorMessage = nil
        showRetryButton = false
    }
}
