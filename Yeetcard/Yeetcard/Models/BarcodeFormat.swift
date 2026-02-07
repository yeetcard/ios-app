//
//  BarcodeFormat.swift
//  Yeetcard
//

import Foundation

enum BarcodeFormat: String, Codable, CaseIterable {
    case qr = "QR"
    case code128 = "Code128"
    case code39 = "Code39"
    case ean13 = "EAN-13"
    case ean8 = "EAN-8"
    case upcA = "UPC-A"
    case upcE = "UPC-E"
    case pdf417 = "PDF417"
    case aztec = "Aztec"
    case dataMatrix = "DataMatrix"

    var displayName: String {
        switch self {
        case .qr: return "QR Code"
        case .code128: return "Code 128"
        case .code39: return "Code 39"
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .upcA: return "UPC-A"
        case .upcE: return "UPC-E"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .dataMatrix: return "Data Matrix"
        }
    }

    var isWalletCompatible: Bool {
        switch self {
        case .qr, .code128, .pdf417, .aztec:
            return true
        case .code39, .ean13, .ean8, .upcA, .upcE, .dataMatrix:
            return false
        }
    }

    var canGenerate: Bool {
        switch self {
        case .qr, .code128, .pdf417, .aztec, .code39, .ean13:
            return true
        case .ean8, .upcA, .upcE, .dataMatrix:
            return false
        }
    }
}
