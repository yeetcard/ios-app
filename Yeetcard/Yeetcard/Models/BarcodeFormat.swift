//
//  BarcodeFormat.swift
//  Yeetcard
//

import Foundation

// Nonisolated so barcode detection can produce formats off the main actor.
nonisolated enum BarcodeFormat: String, Codable, CaseIterable {
    case qr = "QR"
    case code128 = "Code128"
    case code39 = "Code39"
    case ean13 = "EAN-13"
    case ean8 = "EAN-8"
    case upcA = "UPC-A"
    case upcE = "UPC-E"
    case code93 = "Code93"
    case codabar = "Codabar"
    case itf = "ITF"
    case gs1DataBar = "GS1DataBar"
    case msiPlessey = "MSIPlessey"
    case pdf417 = "PDF417"
    case aztec = "Aztec"
    case dataMatrix = "DataMatrix"
    case microQR = "MicroQR"
    case microPDF417 = "MicroPDF417"

    var displayName: String {
        switch self {
        case .qr: return "QR Code"
        case .code128: return "Code 128"
        case .code39: return "Code 39"
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .upcA: return "UPC-A"
        case .upcE: return "UPC-E"
        case .code93: return "Code 93"
        case .codabar: return "Codabar"
        case .itf: return "Interleaved 2 of 5"
        case .gs1DataBar: return "GS1 DataBar"
        case .msiPlessey: return "MSI Plessey"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .dataMatrix: return "Data Matrix"
        case .microQR: return "Micro QR"
        case .microPDF417: return "MicroPDF417"
        }
    }

    var isWalletCompatible: Bool {
        switch self {
        case .qr, .code128, .pdf417, .aztec:
            return true
        case .code39, .ean13, .ean8, .upcA, .upcE, .code93, .codabar, .itf, .gs1DataBar,
             .msiPlessey, .dataMatrix, .microQR, .microPDF417:
            return false
        }
    }

    var canGenerate: Bool {
        switch self {
        case .qr, .code128, .pdf417, .aztec, .code39, .ean13:
            return true
        case .ean8, .upcA, .upcE, .code93, .codabar, .itf, .gs1DataBar, .msiPlessey,
             .dataMatrix, .microQR, .microPDF417:
            return false
        }
    }
}
