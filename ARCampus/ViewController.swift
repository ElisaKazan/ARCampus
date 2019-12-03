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
    
    /// The arrow entity
    var arrowEntity: Entity?
    
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
        
        /// Loads the diorama scene from the RC file  asynchronously
        loadDioramaScene()
    
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
    
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        /// Location that user tapped
        let tapLocation = sender.location(in: arView)
        
        /// Find entity at tapped location
        guard let tappedEntity = arView.entity(at: tapLocation) else {
            print("Error: No entity found.")
            hideBuildingOverlayAndArrowAsync()
            return
        }
        
        /// Check if valid building entity
        guard let buildingEntity = tappedEntity.getBuildingEntity() else {
            print("Error: No building entity found.")
            hideBuildingOverlayAndArrowAsync()
            return
        }
        
        print("You tapped building \(buildingEntity.name)")

        let buildingID = buildingEntity.name
        
        /// Check for valid building code
        guard let building = buildings[buildingID] else {
            print("Error: Invalid building code, no building found.")
            hideBuildingOverlayAndArrowAsync()
            return
        }
        
        /// Update building info overlay view and display
        DispatchQueue.main.async {
            self.highlightSelectedBuilding(buildingEntity: buildingEntity, buildingCode: buildingID)
            self.buildingInfoOverlayView.updateBuildingInfo(building: building, buildingCode: buildingID)
            self.buildingInfoOverlayView.isHidden = false
        }
    }
    
    func hideBuildingOverlayAndArrowAsync() {
        DispatchQueue.main.async {
            self.buildingInfoOverlayView.isHidden = true
            guard let arrow = self.arrowEntity else {
                print("ERROR: Arrow entity not found")
                return
            }
            //arrow.setParent(nil) // Do we want the parent to be nil?
            arrow.isEnabled = false
            
            /// Entities need to be attached to a scene in order to be simulated and rendered.
            /// `isActive` indicates whether an entity is currently being simulated.
            /// Entities can be temporarily disabled by setting `isEnabled` to `false`. The `isEnabled` state
            /// is inherited in the scene hierarchy. This means, setting `isEnabled` to `false` disables all
            /// entities in a subtree (the current entity and all of its children).
        }
    }
    
    func highlightSelectedBuilding(buildingEntity: Entity, buildingCode: String) {
        print("Highlighting building \(buildingCode)...")
        //print("The scenes anchors (probably AnchorEntity): \(arView.scene.anchors)") //this is all of them
        
        //print("Components: \(buildingEntity.components)") // displays HP->HP_1-> etc
        //print("Transform: \(buildingEntity.transform)")
        
        guard let arrow = arrowEntity else {
            print("ERROR: Arrow entity not found")
            return
        }
        
        arrow.isEnabled = true
        
        // ATTEMPT #1
//        var newTransform = arrow.transform
//        print("Current Transform.matrix of Arrow: \(newTransform.matrix)")
//        print("Current Transform.matrix of Building: \(buildingEntity.transform.matrix)")
//
//        print("Current Transform.translation of Arrow: \(newTransform.translation)")
//               print("Current Transform.translation of Building: \(buildingEntity.transform.translation)")
//
//        /// Update the arrows position relative to the buildingEntity
//        newTransform.translation.x =  buildingEntity.transform.translation.x
//        newTransform.translation.z =  buildingEntity.transform.translation.z
//        arrow.setTransformMatrix(newTransform.matrix, relativeTo: buildingEntity)
        
        guard let arrowParent = arrow.parent else {
            print("Error: arrow does not have a parent")
            return
        }
        
        print("Arrow Start Parent is \(arrowParent.name)")
        print("Arrow Start Position is \(arrow.position)")
        
        // An entity has a position -> https://developer.apple.com/documentation/realitykit/entity/3244108-position
        // arrow.position (which is relative to the parent) "This is the same as the translation valye on the transform" Apple docs
        // set the arrow's parent to be the building (may not need to set this if we can set position relative to the building instead
        arrow.setParent(buildingEntity) // should this be before or after setPosition()
        
        let x:Float = 0
        let y:Float = (buildingCode == "DT") ? 0.85 : 0.75 // In meters probably, 0.75 is good for regular buildings, dunton needs taller like 0.85
        let z:Float = 0
        let newPosition = SIMD3(x, y, z)
        arrow.setPosition(newPosition, relativeTo: buildingEntity)
        arrow.setParent(buildingEntity)
        
        print("Arrow End Parent is \(arrowParent.name)")
        print("Arrow End Position is \(arrow.position)")
        print("--")
        
        // Transform: Transform(scale: SIMD3<Float>(0.6000001, 0.6000001, 0.6000001), rotation: simd_quatf(real: 1.0, imag: SIMD3<Float>(0.0, 0.0, 0.0)), translation: SIMD3<Float>(0.13214825, 0.0, 0.33860776))
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
    
    func setArrowEntity(dioramaEntity: Entity) {
        guard let arrow = dioramaEntity.findEntity(named: "Arrow") else {
            print("Error: Arrow entity cannot be found.")
            return
        }
        
        self.arrowEntity = arrow
    }
    
    /// Loads DioramaScene from Reality Composer file
    func loadDioramaScene() {
        Experience.loadDioramaSceneAsync { [weak self] result in
            /// This is the callback for when loading the diorama has completed
            switch result {
            case .success(let loadedDioramaAnchorEntity): // Experience.Diorama, this is the 3D model from reality composer
                print("Diorama has successfully finished loading.")
                guard let self = self else { return }
                
                self.contentIsLoaded = true
                
                // Find and set the arrow entity
                self.setArrowEntity(dioramaEntity: loadedDioramaAnchorEntity)
                                
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
    /// Looks through parents and returns the entity related to a building
    ///
    /// - Returns: The `Entity` of a building or nil.
    func getBuildingEntity()-> Entity? {
        
        // TODO: Improve this
        
        if self.name == "Ground Plane" {
            print("ERROR: Bad entity found (aka Ground Plane).")
            return nil
        }
                
        var currEntity = self
        
        while (currEntity.parent != nil) {
            let parent = currEntity.parent!
            if parent.name == "" { break }
            currEntity = parent
        }
        
        return currEntity
    }
}
