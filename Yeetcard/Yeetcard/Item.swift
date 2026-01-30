//
//  Item.swift
//  Yeetcard
//
//  Created by Rishi Malik on 12/9/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
