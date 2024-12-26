//
//  FC-Button.swift
//  FightClub-Demo
//
//  Created by Edward Lee on 12/24/24.
//

import SwiftUI

struct FCButton: View {
  init(
    _ text: String,
    enabled: Binding<Bool> = .constant(true), // init에 값 안 넣을 시, 기본값 true로.
    action: (() -> Void)?) {
    self.text = text
    self._enabled = enabled
    self.action = action
  }
  var text: String
  var action: (() -> Void)?
  @Binding var enabled: Bool
  var body: some View {
    Button {
      action?()
    } label: {
      if enabled {
        Text(text)
          .font(.system(size: 16))
          .multilineTextAlignment(.center)
          .padding(15)
          .frame(maxWidth: .infinity)
          .foregroundColor(.white)
          .background(.black)
          .cornerRadius(5)
      } else {
        Text(text)
          .font(.system(size: 16))
          .multilineTextAlignment(.center)
          .padding(15)
          .frame(maxWidth: .infinity)
          .foregroundColor(.gray)
          .background(.gray.opacity(0.3))
          .cornerRadius(5)
      }
    }
    .disabled(!enabled)
  }
}

  struct FCButton_Previews: PreviewProvider {
      static var previews: some View {
          FCButton("버튼") {
              print("Button Tapped")
          }
          .padding()
          .previewLayout(.sizeThatFits)
      }
  }
