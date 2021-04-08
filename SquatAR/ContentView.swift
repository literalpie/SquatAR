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
  @State var showingHelp = false
  var body: some View {
    if poopBrains.cameraAccessError {
      Text("This app cannot work without access to the camera!")
      Button("Settings") {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
      }
    } else {
      ZStack {
        ARViewContainer(brains: poopBrains)
          .edgesIgnoringSafeArea(.all)
          .overlay(overlayView)
        VStack {
          if showingHelp {
            VStack {
              Spacer()
              HStack {
                Spacer()
                ARButtonView {
                  withAnimation {
                    showingHelp = false
                  }
                } content: {
                  Image(systemName: "xmark")
                }
                .accessibility(label: Text("Close"))
              }.padding(.horizontal)
              BlurTextView {
                VStack {
                  Text(
                    "To use this app, have someone squat while you look at them through your device. This will cause poop to appear on their butt!\n \n\"3d Poop Emoji\" by Dimensión N is licensed under Creative Commons Attribution.")
                }
              }
              .padding()
              
              Spacer()
            }
            .background(Color.gray.opacity(0.6).edgesIgnoringSafeArea(.all))
          }
        }
        .animation(.easeInOut)
      }
    }
  }

  var overlayView: some View {
    VStack {
      HStack {
        Spacer()
        ARButtonView {
          withAnimation {
            showingHelp = true
          }
        } content: {
          Image(systemName: "questionmark")
        }
        .accessibility(label: Text("Help"))
        ARButtonView {
          poopBrains.resetSession()
        } content: {
          Image(systemName: "arrow.triangle.2.circlepath")
        }
        .accessibility(label: Text("Reset AR Session"))
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
  @Published var poopScale: Float = 1
  @Published var cameraAccessError = false
  weak var arSession: ARSession?

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
        poopingDuration += 1
        let poopScale = Float(poopingDuration) * 0.1
        self.poopScale = max(min(poopScale, 8), 2)
        if !pooping {
          notPoopingDuration = 0
          if poopingDuration > 5 {
            self.pooping = true
          }
        }
        self.poopPosition = otherRoot.translation
      } else if pooping {
        poopingDuration = 0
        notPoopingDuration += 1
        if notPoopingDuration > 5 {
          pooping = false
          poopPosition = nil
        }
      }
    }
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    if (error as? ARError)?.code == .cameraUnauthorized {
      self.cameraAccessError = true
    }
  }

  public func resetSession() {
    let config = ARBodyTrackingConfiguration()
    config.planeDetection = .horizontal
    arSession?.run(config, options: [ARSession.RunOptions.resetTracking])
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

  // trigger when pooping becomes true
  public func startPoop() {
    activePoop = boxAnchor.poop?.clone(recursive: true)
    activePoop?.scale = SIMD3(repeating: 0)
    (activePoop as? HasPhysics)?.physicsBody?.mode = .static
    activePoop?.isEnabled = true
    boxAnchor.addChild(activePoop!)
    pooping = true
  }

  // trigger when position changes
  public func movePoop(to position: SIMD3<Float>, with scale: Float) {
    activePoop?.setPosition(position, relativeTo: nil)
    activePoop?.scale = SIMD3(repeating: scale)
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
    brains.arSession = arView.session
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
      uiView.movePoop(to: position, with: brains.poopScale)
    }
  }
}

struct BlurTextView<Content: View>: View {
  var content: () -> Content
  var body: some View {
    content()
      .foregroundColor(.white)
//      .frame(height: 100, alignment: .center)
      .padding()
      .background(BlurView(style: .dark))
      .clipShape(RoundedRectangle(cornerRadius: 15))
  }
}

#if DEBUG
  struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
      ContentView()
    }
  }
#endif
