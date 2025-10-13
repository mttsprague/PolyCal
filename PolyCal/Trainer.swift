//
//  Trainer.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

struct Trainer: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String
    var email: String
    var avatarUrl: String?
    var photoURL: String?
    var imageUrl: String?
    var active: Bool = true
}
