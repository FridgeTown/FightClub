//
//  ConfirmationView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVKit

struct ConfirmationView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            buttonView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding(.horizontal, 40)
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var buttonView: some View {
        VStack(spacing: 8) {
            Button(action: primaryAction) {
                Text(primaryButtonTitle)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: secondaryAction) {
                Text(secondaryButtonTitle)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
            }
        }
    }
}
