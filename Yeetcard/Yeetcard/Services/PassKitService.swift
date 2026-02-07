//
//  PassKitService.swift
//  Yeetcard
//

import Foundation
import PassKit

enum PassKitError: Error, LocalizedError {
    case notSupported
    case networkError(underlying: Error)
    case serverError(message: String)
    case invalidResponse
    case passCreationFailed
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Apple Wallet is not available on this device"
        case .networkError:
            return "Unable to connect to the server. Please check your internet connection."
        case .serverError(let message):
            return message
        case .invalidResponse:
            return "Received an invalid response from the server"
        case .passCreationFailed:
            return "Failed to create the Wallet pass"
        case .userCancelled:
            return "Pass addition was cancelled"
        }
    }
}

struct PassRequest: Codable {
    let cardName: String
    let barcodeData: String
    let barcodeFormat: String
    let foregroundColor: String
    let backgroundColor: String
}

protocol PassKitServiceProtocol {
    var isWalletAvailable: Bool { get }
    func createPass(for card: Card, foregroundColor: String, backgroundColor: String) async throws -> PKPass
    func isCardInWallet(card: Card) -> Bool
}

extension PassKitServiceProtocol {
    func createPass(for card: Card) async throws -> PKPass {
        try await createPass(for: card, foregroundColor: "#FFFFFF", backgroundColor: "#1A1A2E")
    }
}

final class PassKitService: PassKitServiceProtocol {
    static let shared = PassKitService()

    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let timeout: TimeInterval = 10

    private init() {
        self.baseURL = URL(string: "https://yeetcard-pass-service.example.com")!
        self.apiKey = ProcessInfo.processInfo.environment["YEETCARD_API_KEY"] ?? ""

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: config)
    }

    var isWalletAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    func createPass(for card: Card, foregroundColor: String = "#FFFFFF", backgroundColor: String = "#1A1A2E") async throws -> PKPass {
        guard isWalletAvailable else {
            throw PassKitError.notSupported
        }

        guard card.isWalletCompatible else {
            throw PassKitError.serverError(message: "This barcode format is not supported by Apple Wallet")
        }

        let request = PassRequest(
            cardName: card.name,
            barcodeData: card.barcodeData,
            barcodeFormat: card.barcodeFormat.rawValue,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )

        let passData = try await fetchPassData(request: request)

        guard let pass = try? PKPass(data: passData) else {
            throw PassKitError.passCreationFailed
        }

        return pass
    }

    private func fetchPassData(request: PassRequest) async throws -> Data {
        let url = baseURL.appendingPathComponent("api/v1/passes")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PassKitError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
                guard contentType.contains("application/vnd.apple.pkpass") else {
                    throw PassKitError.invalidResponse
                }
                return data

            case 400, 401, 500:
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                throw PassKitError.serverError(message: errorResponse?.error ?? "Server error")

            default:
                throw PassKitError.invalidResponse
            }
        } catch let error as PassKitError {
            throw error
        } catch {
            throw PassKitError.networkError(underlying: error)
        }
    }

    func isCardInWallet(card: Card) -> Bool {
        guard isWalletAvailable else { return false }

        let library = PKPassLibrary()
        let passes = library.passes()

        return passes.contains { pass in
            pass.localizedName == card.name
        }
    }
}

private struct ErrorResponse: Codable {
    let error: String
}
