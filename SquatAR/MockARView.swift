//
//  MockARView.swift
//  SquatAR
//
//  Created by Benjamin Kindle on 4/30/21.
//

import SwiftUI
import AVKit

extension AVPlayer: ObservableObject { }

struct MockARView: View {
  // for this to work, use ARVideoKit to record a video, and add the file to the project/target.
  @StateObject var video = AVPlayer(url: Bundle.main.url(forResource: "app-recording", withExtension: "MP4")!)
  var body: some View {
    VStack {
      VideoPlayer(player: video)
        .scaledToFill() // use this when making video for edge-to-edge phones
//        .scaleEffect(1.1).offset(x: -22, y: 0) // iphone max
//        .scaleEffect(1.7) // ipad pro 12 inch
                        
        .edgesIgnoringSafeArea(.all)
        .onAppear {
          video.play()
        }
      // Use these when taking screenshots
      // for this to work, I need to add "test" and "selected" assets to teh xcassets file.
    }
    .colorScheme(.light)
  }
}

struct MockARView_Previews: PreviewProvider {
    static var previews: some View {
        MockARView()
    }
}
