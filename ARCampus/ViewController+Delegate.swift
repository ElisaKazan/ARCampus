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
        
        /// WHY DISPATCH? Because we need this to keep the camera working during the coaching overlay
        
        /// Ask the user to gather more data before placing the game into the scene
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            /// Set the view controller as the delegate of the session to get updates per-frame
            self.arView.session.delegate = self
        }
    }
    
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        if debugMode {
            print("STATE - coachingOverlayViewDidDeactivate()")
        }
    }
    
    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        if debugMode {
            print("STATE - coachingOverlayViewDidRequestSessionReset()")
        }
    }
}

/// WHY? Because we need the coaching overlay stuff (above) to see the camera
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
            print("Found valid plane anchor!")
            print("PlaneAnchor Center: \(planeAnchor.center)")
            print("PlaneAnchor Geometry: \(planeAnchor.geometry)")
            print("PlaneAnchor Alignment: \(planeAnchor.alignment)")
            print("PlaneAnchor Transform: \(planeAnchor.transform)")
        }
        
        let dioramaAnchor = ARAnchor(name: "Diorama_Anchor", transform: normalizeMatrix(planeAnchor.transform)) 
        
        /// Add the horizontal plane anchor to the session
        /// https://developer.apple.com/documentation/arkit/arsession/2865612-add
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
        // TODO: Should this have the planeDetection and isCollaborationEnabled properties set or nah?
        //arConfiguration.planeDetection = .horizontal
        //arConfiguration.isCollaborationEnabled = false
        
        /// If ready to display content, place diorama in the real world
        if self.contentIsLoaded && self.planeAnchorIsFound {
            self.placeDioramaInWorld()
        }
    }
    
    // TODO: Understand why normalizing the matrix is important
    func normalizeMatrix(_ matrix: float4x4) -> float4x4 {
        var normalized = matrix
        normalized.columns.0 = simd.normalize(normalized.columns.0)
        normalized.columns.1 = simd.normalize(normalized.columns.1)
        normalized.columns.2 = simd.normalize(normalized.columns.2)
        return normalized
    }
}
