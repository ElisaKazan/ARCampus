//
//  ViewController+Delegate.swift
//  CarletonHonoursProject
//
//  Created by Elisa Kazan on 2019-11-24.
//  Copyright © 2019 ElisaKazan. All rights reserved.
//

import ARKit

extension ViewController: ARCoachingOverlayViewDelegate {
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        
        if debugMode {
            print("STATE - coachingOverlayViewWillActivate()")
        }
                
        /// Ask the user to gather more data before placing the game into the scene
        /// Dispatch to keep camera working during coaching overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            /// Set the view controller as the delegate of the session to get updates per-frame
            self.arView.session.delegate = self
        }
    }
}

extension ViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if debugMode {
            print("STATE - ARSession didUpdate()")
        }
        
        let screenCenter = CGPoint(x: arView.frame.midX, y: arView.frame.midY)
        let arHitTestResults = arView.hitTest(screenCenter, types: [.existingPlaneUsingExtent])
        
        guard let result = arHitTestResults.first(where: { (result) -> Bool in
            
            /// Is the result a good distance from camera or is coaching overlay active?
            guard result.distance > Constants.minAnchorDistance && result.distance < Constants.maxAnchorDistance || self.coachingOverlayView.isActive else {
                return false
            }
            
            /// Is the anchor a horizontal plane?
            guard let resultAnchor = result.anchor as? ARPlaneAnchor, resultAnchor.alignment == .horizontal else {
                return false
            }
            
            /// Is the extent the right size?
            let extentLength = simd_length(resultAnchor.extent)
            
            guard extentLength > Constants.minExtentLength && extentLength < Constants.maxExtentLength else {
                return false
            }
            
            return true
        }), let planeAnchor = result.anchor as? ARPlaneAnchor else {
            return
        }
        
        if debugMode {
            print("Valid plane anchor found!")
        }
        
        let dioramaAnchor = ARAnchor(name: "Diorama_Anchor", transform: normalizeMatrix(planeAnchor.transform)) 
        
        /// Add the horizontal plane anchor to the session
        arView.session.add(anchor: dioramaAnchor)
        
        /// Save this anchor
        self.horizontalPlaneAnchor = dioramaAnchor
        self.planeAnchorIsFound = true
        
        /// Remove the coaching overlay
        self.removeCoachingOverlay()
        
        /// Remove all debug options (aka see the plane detection)
        arView.debugOptions = []
        
        /// Need to remove the VC as ARSessionDelegate to stop getting updates per frame
        self.arView.session.delegate = nil
        
        /// Reset session now that we have the anchor for the diorama
        self.arView.session.run(ARWorldTrackingConfiguration())
        
        /// If ready to display content, place diorama in the real world
        if self.contentIsLoaded && self.planeAnchorIsFound {
            self.placeDioramaInWorld()
        }
    }
    
    func normalizeMatrix(_ matrix: float4x4) -> float4x4 {
        var normalized = matrix
        normalized.columns.0 = simd.normalize(normalized.columns.0)
        normalized.columns.1 = simd.normalize(normalized.columns.1)
        normalized.columns.2 = simd.normalize(normalized.columns.2)
        return normalized
    }
}
