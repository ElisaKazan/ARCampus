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
    /// The view that displays the real world with virtual objects (i.e. Augmented Reality)
    @IBOutlet var arView: ARView!
    
    /// The view that provides instructions for getting a horizontal plane
    @IBOutlet weak var coachingOverlayView: ARCoachingOverlayView!
    
    /// The view that displays building information
    @IBOutlet weak var buildingInfoOverlayView: BuildingInfoOverlayView!
    
    /// The anchor for the DioramaScene from the Reality Composer file
    var dioramaAnchorEntity: Experience.DioramaScene?
    
    /// The plane anchor found by coaching overlay
    var horizontalPlaneAnchor: ARAnchor?
    
    /// A dictionary of building codes to Building objects
    var buildings = [String: Building]()
    
    /// A toggle for print statements
    var debugMode = true
    
    /// Booleans for state
    var contentIsLoaded = false
    var planeAnchorIsFound = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // TODO: Pause the session
    }
    
    func setupView() {
        /// Hide building information view
        self.buildingInfoOverlayView.isHidden = true
        
        // Load building information to dictionary
        loadJSONData()
            
        /// Create ARWorldTrackingConfiguration for horizontal planes
        let arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.planeDetection = .horizontal
        arConfiguration.isCollaborationEnabled = false
            
        /// Include AR debug options
        arView.debugOptions = [.showAnchorGeometry,
                               .showAnchorOrigins,
                               .showWorldOrigin]
            
        /// Run the view's session
        arView.session.run(arConfiguration, options: [])
            
        /// Loads the diorama scene from the RC file  asynchronously
        loadDioramaScene()
        
        /// Instructions for getting a nice horizontal plane
        presentCoachingOverlay()
    }
    
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        /// Location that user tapped
        let tapLocation = sender.location(in: arView)
        
        /// Find entity at tapped location and check if valid building (no entity tapped, invalid building code)
        guard let buildingEntity = arView.entity(at: tapLocation), isBuilding(entity: buildingEntity)  else {
            print("Error: Invalid entity found.")
            hideBuildingOverlayAndArrow()
            return
        }
        
        /// Building codes are two capital letters (ex: UC for University Center)
        let buildingCode = buildingEntity.name
        
        if debugMode {
            print("You tapped building \(buildingCode)")
        }

        /// Check for valid building code
        guard let building = buildings[buildingCode] else {
            print("Error: Invalid building code, no building found.")
            hideBuildingOverlayAndArrow()
            return
        }
        
        /// Move arrow to selected building
        self.highlightSelectedBuilding(buildingEntity: buildingEntity, buildingCode: buildingCode)
        
        /// Update building info overlay view and display
        self.buildingInfoOverlayView.updateBuildingInfo(building: building, buildingCode: buildingCode)
        self.buildingInfoOverlayView.isHidden = false
    }
    
    /// Check if entity is a valid building
    func isBuilding(entity: Entity) -> Bool {
        return buildings[entity.name] != nil
    }
    
    /// Loops over all ArrowBlocks and hides them
    func hideAllArrowBlocks(diorama: Experience.DioramaScene) {
        for level1ChildEntity in diorama.children {
            for level2ChildEntity in level1ChildEntity.children {
                for buildingEntity in level2ChildEntity.children {
                    if debugMode {
                        print("Building: \(buildingEntity.name)")
                    }
                    
                    guard let arrowBlockEntity = buildingEntity.findEntity(named: Strings.arrowBlock) else {
                        print("Error: Cannot find ArrowBlock for \(buildingEntity.name) entity")
                        continue
                    }
                    
                    /// Hide block by setting isEnabled to false
                    arrowBlockEntity.isEnabled = false
                }
            }
        }
    }
    
    /// Function for debugging purposes only, visually displays the entity hierarchy from the DioramaScene
    func printSceneHierarchy(diorama: Experience.DioramaScene) {
        print("Printing hierarchy for diorama...")
        
        for level1ChildEntity in diorama.children {
            print("Level 1 Child: \(level1ChildEntity.name)")
            
            for level2ChildEntity in level1ChildEntity.children {
                print("  Level 2 Child: \(level2ChildEntity.name)")
                
                for level3ChildEntity in level2ChildEntity.children {
                    print("    Level 3 Child: \(level3ChildEntity.name)")
                    
                    for level4ChildEntity in level3ChildEntity.children {
                        print("      Level 4 Child: \(level4ChildEntity.name)")
                        
                        for level5ChildEntity in level4ChildEntity.children {
                            print("        Level 5 Child: \(level5ChildEntity.name)")
                            
                        }
                    }
                }
            }
        }
    }
    
    func hideBuildingOverlayAndArrow() {
        /// Hide Building Overlay
        self.buildingInfoOverlayView.isHidden = true
        
        /// Hide arrow
        guard let dioramaAnchor = self.dioramaAnchorEntity else {
            print("Error: DioramaAnchorEntity is nil")
            return
        }
        
        guard let arrowEntity = dioramaAnchor.getArrowEntity() else {
            print("Error: ArrowEntity is nil")
            return
        }
        
        arrowEntity.isEnabled = false
    }
    
    /// Move the arrow entity to show which building has been selected
    /// - Parameters:
    ///   - buildingEntity: the building entity of the tapped building
    ///   - buildingCode: the building code (ex: HP) of the tapped building
    func highlightSelectedBuilding(buildingEntity: Entity, buildingCode: String) {
        
        guard let dioramaAnchor = self.dioramaAnchorEntity else {
            print("Error: DioramaAnchorEntity is nil")
            return
        }
        
        guard let arrowEntity = dioramaAnchor.getArrowEntity() else {
            print("Error: ArrowEntity is nil")
            return
        }

        /// Show arrow
        arrowEntity.isEnabled = true
        
        /// The ArrowBlock of the building
        guard let arrowBlockEntity = buildingEntity.findEntity(named: Strings.arrowBlock) else {
            print("Error: Cannot find ArrowBlock for tapped building.")
            return
        }
        
        if debugMode {
            print("Highlighting building \(buildingCode)...")
            print("Arrow Start position: \(arrowEntity.position)")
            print("ArrowBlock Position: \(arrowBlockEntity.position)")
        }
        
        // TODO: Do we need the ArrowBlock to be the parent of the arrow?
        //arrowEntity.setParent(arrowBlockEntity)
        
        /// Move the arrow to the selected building using the ArrowBlock
        arrowEntity.setPosition(.zero, relativeTo: arrowBlockEntity)
        
        

        if debugMode {
            print("Arrow End position: \(arrowEntity.position)")
            print("--")
        }
    }
    
    func presentCoachingOverlay() {
        /// Prevent device from sleeping during idle coaching (coaching phase may take a while and typically expects no touch events)
        UIApplication.shared.isIdleTimerDisabled = true
        
        coachingOverlayView.session = arView.session
        /// The VC must also act as a view delegate for the coachingOverlayView
        coachingOverlayView.delegate = self
        coachingOverlayView.goal = .horizontalPlane
        coachingOverlayView.activatesAutomatically = false
        self.coachingOverlayView.setActive(true, animated: true)
    }
    
    func removeCoachingOverlay() {
        // TODO: Check if this is true
        /// No longer need to prevent sleeping as touch events are expected
        UIApplication.shared.isIdleTimerDisabled = false
        
        coachingOverlayView.delegate = nil
        coachingOverlayView.setActive(false, animated: false)
        coachingOverlayView.removeFromSuperview()
    }
    
    func placeDioramaInWorld() {
        /// Check that both conditions are met
        if !contentIsLoaded || !planeAnchorIsFound {
            print("Error: At least one condition is not met.")
        }
        
        guard let planeAnchor = horizontalPlaneAnchor, let dioramaAnchor = dioramaAnchorEntity else {
            print("Error: dioramaAnchorEntity is nil.")
            return
        }
        
        /// Create anchor entity from plane anchor
        let planeAnchorEntity = AnchorEntity(anchor: planeAnchor)
        
        /// Scale anchor
        if debugMode {
            print("AnchorEntity Scale Before: \(dioramaAnchor.scale)")
        }
        
        let scale:Float = 0.25
        dioramaAnchor.setScale([scale, scale, scale], relativeTo: planeAnchorEntity)
        
        if debugMode {
            print("AnchorEntity Scale After: \(dioramaAnchor.scale)")
        }
        
        // TODO: what's the difference between addAnchor to scene and anchors.append()
        /// Add anchor to scene
        self.arView.scene.addAnchor(dioramaAnchor)
        
        if debugMode {
            print("Anchors: \(self.arView.scene.anchors)")
        }
 
        /// Add TapGestureRecognizer for tap functionality
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    /// Loads DioramaScene from Reality Composer file
    func loadDioramaScene() {
        Experience.loadDioramaSceneAsync { [weak self] result in
            /// This is the callback for when loading the diorama has completed
            switch result {
            case .success(let loadedDioramaAnchorEntity):
                guard let self = self else { return }
                
                if self.debugMode {
                    print("Diorama has successfully finished loading.")
                }

                /// Update state
                self.contentIsLoaded = true
                
                /// Hide all arrow block entities
                self.hideAllArrowBlocks(diorama: loadedDioramaAnchorEntity)
                
                /// Hide the arrow entity
                guard let arrowEntity = loadedDioramaAnchorEntity.getArrowEntity() else {
                    print("Error: Cannot find arrow entity")
                    return
                }
                
                arrowEntity.isEnabled = false
                
                /// Update dioramaAnchorEntity and place diorama in real world
                if self.dioramaAnchorEntity == nil {
                    self.dioramaAnchorEntity = loadedDioramaAnchorEntity
                                                  
                    /// The case where plane anchor is found first
                    if self.contentIsLoaded && self.planeAnchorIsFound {
                        self.placeDioramaInWorld()
                    }
                }
            case .failure(let error):
                fatalError("Error: Unable to load the scene with error: \(error.localizedDescription)")
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

extension Experience.DioramaScene {
    func getArrowEntity() -> Entity? {
        return self.findEntity(named: Strings.arrow)
    }
}
