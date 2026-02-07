//
//  Card.swift
//  Yeetcard
//

import Foundation
import SwiftData

@Model
final class Card {
    var id: UUID
    var name: String
    var barcodeData: String
    var barcodeFormatRaw: String
    var imagePath: String
    var thumbnailPath: String
    var isInWallet: Bool
    var isFavorite: Bool
    var notes: String
    var dateAdded: Date
    var lastUsed: Date?
    var group: CardGroup?

    var barcodeFormat: BarcodeFormat {
        get {
            BarcodeFormat(rawValue: barcodeFormatRaw) ?? .qr
        }
        set {
            barcodeFormatRaw = newValue.rawValue
        }
    }

    var isWalletCompatible: Bool {
        barcodeFormat.isWalletCompatible
    }

    init(
        id: UUID = UUID(),
        name: String,
        barcodeData: String,
        barcodeFormat: BarcodeFormat,
        imagePath: String = "",
        thumbnailPath: String = "",
        isInWallet: Bool = false,
        isFavorite: Bool = false,
        notes: String = "",
        dateAdded: Date = Date(),
        lastUsed: Date? = nil,
        group: CardGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.barcodeData = barcodeData
        self.barcodeFormatRaw = barcodeFormat.rawValue
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.isInWallet = isInWallet
        self.isFavorite = isFavorite
        self.notes = notes
        self.dateAdded = dateAdded
        self.lastUsed = lastUsed
        self.group = group
    }
}
