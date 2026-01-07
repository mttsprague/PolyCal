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
    var athleteFirstName: String?
    var athleteLastName: String?
    var athleteBirthday: String?
    var athlete2FirstName: String?
    var athlete2LastName: String?
    var athlete2Birthday: String?
    var athlete3FirstName: String?
    var athlete3LastName: String?
    var athlete3Birthday: String?
    var athletePosition: String?
    var athlete2Position: String?
    var athlete3Position: String?
    var notesForCoach: String?

    var fullName: String { "\(firstName) \(lastName)" }
    
    var initials: String {
        let first = firstName.prefix(1).uppercased()
        let last = lastName.prefix(1).uppercased()
        return "\(first)\(last)"
    }
    
    var athleteFullName: String? {
        guard let first = athleteFirstName, let last = athleteLastName else { return nil }
        return "\(first) \(last)"
    }
    
    var athlete2FullName: String? {
        guard let first = athlete2FirstName, let last = athlete2LastName else { return nil }
        return "\(first) \(last)"
    }
    
    var athlete3FullName: String? {
        guard let first = athlete3FirstName, let last = athlete3LastName else { return nil }
        return "\(first) \(last)"
    }
}
