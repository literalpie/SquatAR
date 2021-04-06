//
//  ARButtonView.swift
//  SquatAR
//
//  Created by Benjamin Kindle on 4/6/21.
//

import SwiftUI

struct ARButtonView: View {
  var action: () -> Void
  var content: () -> Image
  
  var body: some View {
    Button(action: action) {
      content()
        .foregroundColor(.white)
        .frame(width: 10, height: 10, alignment: .center)
        .padding()
        .background(BlurView(style: .dark))
        .clipShape(Circle())
    }
  }
  
  init(action: @escaping () -> Void, content: @escaping () -> Image) {
    self.action = action
    self.content = content
  }
}

struct BlurView: UIViewRepresentable {
  
  let style: UIBlurEffect.Style
  
  func makeUIView(context: UIViewRepresentableContext<BlurView>) -> UIView {
    let view = UIView(frame: .zero)
    view.backgroundColor = .clear
    let blurEffect = UIBlurEffect(style: style)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.translatesAutoresizingMaskIntoConstraints = false
    view.insertSubview(blurView, at: 0)
    NSLayoutConstraint.activate([
      blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
      blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
    ])
    return view
  }
  
  func updateUIView(
    _ uiView: UIView,
    context: UIViewRepresentableContext<BlurView>
  ) {
  }
}

struct ARButtonView_Previews: PreviewProvider {
  static var previews: some View {
    ARButtonView(action: {}) {
      Image(uiImage: UIImage(systemName: "trash")!)
    }
  }
}

