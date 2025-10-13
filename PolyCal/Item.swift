//
//  Item.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
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
