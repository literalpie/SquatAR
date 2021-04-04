//
//  ContentView.swift
//  SquatAR
//
//  Created by Benjamin Kindle on 12/13/20.
//

import ARKit
import RealityKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    ARViewContainer()
      .edgesIgnoringSafeArea(.all)
  }
}

class PoopArView: ARView, ARCoachingOverlayViewDelegate, ARSessionDelegate {
  var pooping = false
  var activePoop: Entity?
  var poopSize = 0
  var boxAnchor: Experience.Box!  // includes the poop, floor, and environment to make gravity work
  var baseIndicator: ModelEntity!
  var bodyEntity: Entity = Entity()  // just used to position base (which is hidden)
  let proportionLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
  let heightLabel = UILabel(frame: CGRect(x: 0, y: 100, width: 300, height: 100))
  let distanceLabel = UILabel(frame: CGRect(x: 0, y: 200, width: 300, height: 100))

  func addCoaching() {
    proportionLabel.text = "hi"
    self.addSubview(proportionLabel)
    self.addSubview(distanceLabel)
    self.addSubview(heightLabel)

    let coachingOverlay = ARCoachingOverlayView()
    coachingOverlay.delegate = self
    coachingOverlay.session = self.session
    session.delegate = self
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

  public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    for anchor in anchors {
      guard let bodyAnchor = anchor as? ARBodyAnchor
      else { continue }
      let otherRoot = Transform(matrix: bodyAnchor.transform)
      bodyEntity.setPosition(otherRoot.translation, relativeTo: nil)
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
        print("unexpected joint order")
        return
      }
      let upLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[2])
      let rightUpLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[7])
      let midLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[3])
      let rightMidLegTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[8])
      let footTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[4])
      let toesTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[5])
      let toesEndTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[6])
      let rightFootTransform = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[9])
      let baseX = (footTransformThing.translation.x + rightFootTransform.translation.x) / 2
      let baseY = (footTransformThing.translation.y + rightFootTransform.translation.y) / 2
      let baseZ = (footTransformThing.translation.z + rightFootTransform.translation.z) / 2
      baseIndicator.setPosition(SIMD3(baseX, baseY, baseZ), relativeTo: bodyEntity)

      //      baseIndicator.isEnabled = true // keep commented out since it's ugly.
      let headTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[51])
      let personHeight = distance(headTransformThing.translation, footTransformThing.translation)
//      let headTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[4])

//      let personsHeight =

      let rootTransformThing = Transform(matrix: bodyAnchor.skeleton.jointModelTransforms[0])
      let feetDistance = distance(footTransformThing.translation, rootTransformThing.translation)
      // this proportion thing doesn't seem to be working. Maybe compare the y difference of the knee joint and the hip joint vs. the foot and the hip.
      let proportion = feetDistance / personHeight
      let leftLowerLegLength = midLegTransformThing.translation.y - footTransformThing.translation.y
      let leftUpperLegLength = upLegTransformThing.translation.y - midLegTransformThing.translation.y
      let rightLowerLegLength = rightMidLegTransformThing.translation.y - rightFootTransform.translation.y
      let rightUpperLegLength = rightUpLegTransformThing.translation.y - rightMidLegTransformThing.translation.y
    
      proportionLabel.text = "lowerLegLength: \(midLegTransformThing.translation.y - footTransformThing.translation.y)"
      distanceLabel.text = "upperLength: \(upLegTransformThing.translation.y - midLegTransformThing.translation.y)"
      heightLabel.text = "toe diff: \(footTransformThing.translation.y - toesEndTransformThing.translation.y)"
      if leftUpperLegLength < leftLowerLegLength * 0.6 && rightUpperLegLength < rightLowerLegLength * 0.6 {
        if !pooping {
          activePoop = boxAnchor.poop?.clone(recursive: true)
          (activePoop as? HasPhysics)?.physicsBody?.mode = .static
          activePoop?.isEnabled = true
          boxAnchor.addChild(activePoop!)
          pooping = true
        }
        poopSize += 1
        var translation = otherRoot.translation
        translation.y = translation.y - 1
        activePoop?.setPosition(translation, relativeTo: nil)

        // it was pooping, but not anymore
      } else if pooping {
        pooping = false
        (activePoop as? HasPhysics)?.physicsBody?.mode = PhysicsBodyMode.dynamic  // add gravity
        poopSize = 0
      }
    }

  }

}

struct ARViewContainer: UIViewRepresentable {

  func makeUIView(context: Context) -> PoopArView {
    let arView = PoopArView(frame: .zero)
    arView.addCoaching()
    let config = ARBodyTrackingConfiguration()
    config.planeDetection = .horizontal
    arView.session.run(config, options: [])
    return arView
  }

  func updateUIView(_ uiView: PoopArView, context: Context) {}

}

#if DEBUG
  struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
      ContentView()
    }
  }
#endif
