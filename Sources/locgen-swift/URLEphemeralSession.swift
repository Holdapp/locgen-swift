//
//  File.swift
//  
//
//  Created by Łukasz Szyszkowski on 26/05/2023.
//

import Foundation

extension URLSession {
    static let sharedEphemeral = URLSession(configuration: .ephemeral)
}
