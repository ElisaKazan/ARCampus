//
//  ViewController.swift
//  CarletonHonoursProject
//
//  Created by Elisa Kazan on 2019-11-24.
//  Copyright © 2019 ElisaKazan. All rights reserved.
//

import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var coachingOverlayView: ARCoachingOverlayView!
    @IBOutlet weak var buildingInfoOverlayView: BuildingInfoOverlayView!
    
    /// The anchor for the RealityComposer file
    var dioramaAnchorEntity: Experience.DioramaScene?
    
    /// The plane anchor found by coaching overlay
    var horizontalPlaneAnchor: ARAnchor?
    
    var buildings = [String: Building]()
    
    var debugMode = true
    var useDiorama = true
    
    /// Booleans for state
    var contentIsLoaded = false
    var planeAnchorIsFound = false
    
    // Building information
    var currentBuilding: Building?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.buildingInfoOverlayView.isHidden = true
        
        loadJSONData()
        
        /// Create ARWorldTrackingConfiguration for horizontal planes
        let arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.planeDetection = .horizontal
        arConfiguration.isCollaborationEnabled = false
        
        /// Include AR debug options
        if debugMode {
            arView.debugOptions = [.showAnchorGeometry,
                                   .showAnchorOrigins,
                                   .showWorldOrigin]
        }
        
        // TODO: See if we want to use additional AR options
        /// Run the view's session
        arView.session.run(arConfiguration, options: [])
        
        /// Load the diorama from the RC file (this is done asynchronously
        loadDiorama()
    
        /// Instructions for getting a nice horizontal plane
        presentCoachingOverlay()
        
        /// ORIGINAL AR CODE
        
        /// Load the "Box" scene from the "Experience" Reality File
        //let boxAnchor = try! Experience.loadBox()
        
        /// Add the box anchor to the scene
        //arView.scene.anchors.append(boxAnchor)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // TODO: Pause the session
    }
    
    
    // TODO: Test that this happens
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        /// Location that user tapped
        let tapLocation = sender.location(in: arView)
        
        /// Find entity at tapped location
        guard let tappedEntity = arView.entity(at: tapLocation) else {
            DispatchQueue.main.async {
                self.buildingInfoOverlayView.isHidden = true
            }
            return
        }
        
        /// Check if valid building entity
        guard let buildingEntity = tappedEntity.getBuildingEntity() else {
            print("Error: No building was found")
            DispatchQueue.main.async {
                self.buildingInfoOverlayView.isHidden = true
            }
            return
        }
        
        let buildingID = buildingEntity.name
        
        /// Check for valid building code
        guard let building = buildings[buildingID] else {
            print("Error: Invalid building code, no building found.")
            DispatchQueue.main.async {
                self.buildingInfoOverlayView.isHidden = true
            }
            return
        }
        
        /// Update building info overlay view and display
        DispatchQueue.main.async {
            self.buildingInfoOverlayView.updateBuildingInfo(building: building, buildingCode: buildingID)
            self.buildingInfoOverlayView.isHidden = false
        }
    }
    
    func presentCoachingOverlay() {
        /// Prevent power idle during coaching (coaching phase may take a while and typically expects no touch events)
        UIApplication.shared.isIdleTimerDisabled = true
        
        coachingOverlayView.session = arView.session
        /// The VC must also act as a view delegate for the coachingOverlayView
        coachingOverlayView.delegate = self
        coachingOverlayView.goal = .horizontalPlane
        coachingOverlayView.activatesAutomatically = false
        self.coachingOverlayView.setActive(true, animated: true)
        
    }
    
    func placeDioramaInWorld() {
        /// Double check that conditions are met
        if !contentIsLoaded || !planeAnchorIsFound {
            print("ERROR: At least one condition is not met.")
        }
        
        guard let planeAnchor = horizontalPlaneAnchor, let dioramaAnchor = dioramaAnchorEntity else {
            print("ERROR: dioramaAnchorEntity is nil.")
            return
        }
        
        /// Note: horizontalPlaneAnchor has been added to the session
        print("Anchors: \(self.arView.scene.anchors)")
        
        // TODO: Connect anchors!
        //self.arView.scene.anchors.append(planeAnchor)
        //self.arView.scene.anchors.append(dioramaAnchor)
        
        // Create anchor entity from plane anchor
        let planeAnchorEntity = AnchorEntity(anchor: planeAnchor)
        
        print("Scale Before: \(dioramaAnchor.scale)")
        
        let scale:Float = 0.25
        
        dioramaAnchor.setScale([scale, scale, scale], relativeTo: planeAnchorEntity)

        print("Scale After: \(dioramaAnchor.scale)")
        
        print("DIORAMA dioramaAnchor Orientation: \(dioramaAnchor.orientation)")
        print("DIORAMA dioramaAnchor Transform: \(dioramaAnchor.transform)")
        
        // TODO: what's the difference between addAnchor to scene and anchors.append()
        self.arView.scene.addAnchor(dioramaAnchor)
        
        print("Scene Anchors: \(self.arView.scene.anchors)")
                
        /// Tap functionality
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    /// Loads Diorama from Reality Composer file
    func loadDiorama() {
        Experience.loadDioramaSceneAsync { [weak self] result in
            /// This is the callback for when loading the diorama has completed
            switch result {
            case .success(let loadedDioramaAnchorEntity): // Experience.Diorama, this is the 3D model from reality composer
                print("Diorama has successfully finished loading.")
                guard let self = self else { return }
                
                self.contentIsLoaded = true
                                
                if self.dioramaAnchorEntity == nil {
                    self.dioramaAnchorEntity = loadedDioramaAnchorEntity
                              
                    /// The case where plane anchor is found first
                    if self.contentIsLoaded && self.planeAnchorIsFound {
                        self.placeDioramaInWorld()
                    }
                }
            case .failure(let error):
                print("ERROR: Unable to load the scene with error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Parses building data from JSON file and populates buildings dictionary
    func loadJSONData() {
        /// Get url for JSON file
        guard let url = Bundle.main.url(forResource: "buildings", withExtension: "json") else {
            fatalError("Error: Unable to find buildings JSON in bundle")
        }
        
        /// Load JSON data
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Error: Unable to load JSON")
        }
        
        let decoder = JSONDecoder()
        
        /// Decode the JSON data into a dictionary
        guard let loadedBuildings = try? decoder.decode([String: Building].self, from: data) else {
            fatalError("Error: Unable to parse JSON")
        }
        
        /// Save buildings
        buildings = loadedBuildings
    }
}

extension Entity {
    /// Looks from child to parents until building parent is found
    func getBuildingEntity()-> Entity? {
        
        if self.name == "Ground Plane" {
            print("ERROR: Bad entity found (aka Ground Plane).")
            return nil
        }
                
        var currEntity = self
        
        while (currEntity.parent != nil) {
            let parent = currEntity.parent!
            if parent.name == "" { break }
            //print("Found parent \(parent.name)")
            currEntity = parent
        }
        
        print("Final Parent Entity = \(currEntity.name)")
        return currEntity
    }
}
