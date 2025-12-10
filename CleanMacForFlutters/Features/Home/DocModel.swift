//
//  Untitled.swift
//  CleanMacForFlutters
//
//  Created by André  Lucas on 09/12/25.
//

import Foundation

struct DocModel: Identifiable, Hashable {
    
    let id = UUID()
    let path: String
    var activated: Bool
    
}
