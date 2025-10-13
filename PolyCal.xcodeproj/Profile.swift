//
//  Profile.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

struct Profile: Identifiable, Hashable {
    var id: String { email ?? UUID().uuidString }
    var displayName: String?
    var email: String?
    var photoURL: URL?
}
