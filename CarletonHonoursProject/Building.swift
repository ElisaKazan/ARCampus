//
//  Building.swift
//  CarletonHonoursProject
//
//  Created by Elisa Kazan on 2019-11-29.
//  Copyright © 2019 ElisaKazan. All rights reserved.
//

import Foundation

struct Building: Decodable, CustomStringConvertible {
    let name: String
    let summary: String
    private let food: String
    private let floors: Int
    
    var foodString: String {
        return "Food: \(food)"
    }
    
    var floorString: String {
        return "Floors: \(floors)"
    }
    
    var description: String {
        return "\(name): \(summary), \(foodString) and \(floorString)"
    }
}
