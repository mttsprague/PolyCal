//
//  Client.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

struct Client: Identifiable, Codable, Hashable {
    var id: String
    var firstName: String
    var lastName: String
    var emailAddress: String
    var phoneNumber: String
    var photoURL: String?

    var fullName: String { "\(firstName) \(lastName)" }
}
