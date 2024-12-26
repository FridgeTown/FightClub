//
//  FCTextField.swift
//  FightClub-Demo
//
//  Created by Edward Lee on 12/24/24.
//
import SwiftUI

struct FCTextField: View {
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType
    var isSecure: Bool
    var onCommit: (() -> Void)?
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        isSecure: Bool,
        onCommit: ( () -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.onCommit = onCommit
    }
    
    var body: some View {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text, onCommit: {
                        onCommit?()
                    })
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5)
                    .keyboardType(keyboardType)
                } else {
                    TextField(placeholder, text: $text, onCommit: {
                        onCommit?()
                    })
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5)
                    .keyboardType(keyboardType)
                }
            }
            .font(.system(size: 16))
            .padding(.horizontal, 5)
        }
}
