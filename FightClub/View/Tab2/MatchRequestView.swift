//
//  MatchRequestView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct MatchRequestView: View {
    let matchRequests: [MatchRequest]

    var body: some View {
        VStack(spacing: 16) {
            Text("스파링 요청")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.mainRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ForEach(matchRequests) { request in
                VStack {
                    HStack(spacing: 20) {
                        // 프로필 이미지
                        Image("profile_placeholder")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.mainRed, Color.mainRed.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(radius: 3)
                        
                        // 사용자 정보
                        Text(request.nickname)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // 수락/거절 버튼
                        HStack(spacing: 12) {
                            ActionButton(
                                action: { print("Declined \(request.nickname)") },
                                icon: "xmark",
                                color: Color.mainRed,
                                size: 44
                            )
                            
                            ActionButton(
                                action: { print("Accepted \(request.nickname)") },
                                icon: "checkmark",
                                color: Color.mainRed,
                                size: 44
                            )
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.mainRed.opacity(0.05), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.mainRed.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding()
    }
}

// MARK: - ActionButton
struct ActionButton: View {
    let action: () -> Void
    let icon: String
    let color: Color
    let size: CGFloat
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.opacity(0.15))
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(color)
                )
                .frame(width: size, height: size)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - ScaleButtonStyle
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Models
struct MatchRequest: Identifiable {
    let id: Int
    let nickname: String
}

// MARK: - Preview
struct MatchRequestView_Previews: PreviewProvider {
    static var previews: some View {
        MatchRequestView(matchRequests: [
            MatchRequest(id: 1, nickname: "Boxer1"),
            MatchRequest(id: 2, nickname: "Boxer2"),
            MatchRequest(id: 3, nickname: "Boxer3")
        ])
        .background(Color(.systemGroupedBackground))
    }
}
