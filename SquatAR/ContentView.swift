//
//  ContentView.swift
//  SquatAR
//
//  Created by Benjamin Kindle on 12/13/20. But please don't hold it against me.
//

import ARKit
import RealityKit
import SwiftUI
import os.log

struct ContentView: View {
  @ObservedObject var poopBrains = PoopBrains()
  
  var body: some View {
    ARViewContainer(brains: poopBrains)
      .edgesIgnoringSafeArea(.all)
      .overlay(overlayView)
  }
  
  var overlayView: some View {
    VStack {
      HStack {
        Spacer()
        ARButtonView {
          poopBrains.resetSession()
        } content: {
          Image(systemName: "arrow.triangle.2.circlepath")
        }
        .padding()
      }
      Spacer()
    }
  }
}

class PoopBrains: NSObject, ARSessionDelegate, ObservableObject {
  @Published var pooping = false
  var poopingDuration = 0
  var notPoopingDuration = 0
  @Published var poopPosition: SIMD3<Float>?
  weak var session: ARSession?

  public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    for anchor in anchors {
      guard let bodyAnchor = anchor as? ARBodyAnchor
      else { continue }
      let otherRoot = Transform(matrix: bodyAnchor.transform)
      let jointNames = bodyAnchor.skeleton.definition.jointNames
      guard jointNames[1] == "hips_joint",
            jointNames[2] == "left_upLeg_joint",
            jointNames[3] == "left_leg_joint",
            jointNames[4] == "left_foot_joint",
            jointNames[5] == "left_toes_joint",
            jointNames[6] == "left_toesEnd_joint",
            jointNames[7] == "right_upLeg_joint",
            jointNames[8] == "right_leg_joint",
            jointNames[9] == "right_foot_joint",
            jointNames[51] == "head_joint"
      else {
        os_log(.error, "Unexpected joint order")
        return
      }
      let upLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[2])
      let rightUpLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[7])
      let midLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[3])
      let rightMidLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[8])
      let footTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[4])
      let rightFootTransform = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[9])

      let leftLowerLegLength = midLegTransformThing.translation.y - footTransformThing.translation.y
      let leftUpperLegLength = upLegTransformThing.translation.y - midLegTransformThing.translation.y
      let rightLowerLegLength = rightMidLegTransformThing.translation.y - rightFootTransform.translation.y
      let rightUpperLegLength = rightUpLegTransformThing.translation.y - rightMidLegTransformThing.translation.y

      if leftUpperLegLength < leftLowerLegLength * 0.6 && rightUpperLegLength < rightLowerLegLength * 0.6 {
        if !pooping {
          poopingDuration = 0
          notPoopingDuration += 1
          if notPoopingDuration > 5 {
            self.pooping = true
          }
        }
        var translation = otherRoot.translation
        translation.y = translation.y - 1 // I think this is because the position of the poop model is off
        self.poopPosition = translation
        
      } else if pooping {
        poopingDuration += 1
        if poopingDuration > 5 {
          pooping = false
          poopPosition = nil          
        }
      }
    }
  }
  
  public func resetSession() {
    let config = ARBodyTrackingConfiguration()
    config.planeDetection = .horizontal
    session?.run(config, options: [ARSession.RunOptions.resetTracking])
  }
}

class PoopArView: ARView, ARCoachingOverlayViewDelegate {
  var pooping = false
  var activePoop: Entity?
  var poopSize = 0
  var boxAnchor: Experience.Box!  // includes the poop, floor, and environment to make gravity work
  var baseIndicator: ModelEntity!
  
  func addCoaching() {
    let coachingOverlay = ARCoachingOverlayView()
    coachingOverlay.delegate = self
    coachingOverlay.session = self.session
    coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    coachingOverlay.goal = .anyPlane
    self.addSubview(coachingOverlay)
  }

  public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
    boxAnchor = try! Experience.loadBox()

    (boxAnchor.poop as? HasPhysics)?.physicsBody?.mode = .static
    boxAnchor.poop?.isEnabled = false
    self.scene.addAnchor(boxAnchor)

    baseIndicator = ModelEntity(
      mesh: .generatePlane(width: 0.5, depth: 0.5, cornerRadius: 0.5),
      materials: [SimpleMaterial(color: .blue, isMetallic: true)])
    baseIndicator.isEnabled = false
    boxAnchor.addChild(baseIndicator)
  }

  public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {

  }
  
  // trigger when pooping becomes true
  public func startPoop() {
    activePoop = boxAnchor.poop?.clone(recursive: true)
    (activePoop as? HasPhysics)?.physicsBody?.mode = .static
    activePoop?.isEnabled = true
    boxAnchor.addChild(activePoop!)
    pooping = true
  }
  
  // trigger when position changes
  public func movePoop(to position: SIMD3<Float>) {
    activePoop?.setPosition(position, relativeTo: nil)
  }
  
  // trigger when pooping becomes false
  public func dropPoop() {
    pooping = false
    (activePoop as? HasPhysics)?.physicsBody?.mode = PhysicsBodyMode.dynamic  // add gravity
    poopSize = 0
  }

}

struct ARViewContainer: UIViewRepresentable {
  @ObservedObject var brains = PoopBrains()

  func makeUIView(context: Context) -> PoopArView {
    let arView = PoopArView(frame: .zero)
    arView.addCoaching()
    arView.session.delegate = brains
    brains.session = arView.session
    brains.resetSession()
    return arView
  }

  func updateUIView(_ uiView: PoopArView, context: Context) {
    if self.brains.pooping && !uiView.pooping {
      uiView.startPoop()
    }
    if !brains.pooping && uiView.pooping {
      uiView.dropPoop()
    }
    
    if let position = brains.poopPosition {
      uiView.movePoop(to: position)
    }
  }

}

#if DEBUG
  struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
      ContentView()
    }
  }
#endif
