//
//  OverlayView.swift
//  CarletonHonoursProject
//
//  Created by Elisa Kazan on 2019-11-30.
//  Copyright © 2019 ElisaKazan. All rights reserved.
//

import UIKit

/// View that displays building information
class BuildingInfoOverlayView: UIView {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var summaryLabel: UILabel!
    @IBOutlet var foodLabel: UILabel!
    @IBOutlet var floorLabel: UILabel!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.cornerRadius = 14
        layer.masksToBounds = true
    }
    
    /// Updates the labels and image of the view given a building and its building code
    func updateBuildingInfo(building: Building, buildingCode: String) {
        imageView.image = UIImage(named: buildingCode)
        nameLabel.text = building.name
        summaryLabel.text = building.summary
        foodLabel.text = building.foodString
        floorLabel.text = building.floorString
    }
}
