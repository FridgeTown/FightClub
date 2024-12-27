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
            ForEach(matchRequests) { request in
                HStack(spacing: 16) {
                    // 프로필 이미지
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image("profile_placeholder") // 프로필 이미지
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    
                    // 사용자 정보
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.nickname)
                            .font(.headline)
                        
                        HStack(spacing: 6) {
                            Text("\(request.weight)kg")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Divider()
                                .frame(height: 14)
                                .background(Color.secondary.opacity(0.4))
                            Text("\(request.height)cm")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 수락/거절 버튼
                    VStack(spacing: 8) {
                        CircularIconButton(
                            action: {
                                print("Accepted \(request.nickname)")
                            },
                            icon: "checkmark.circle.fill",
                            gradientColors: [Color.green, Color.teal]
                        )
                        
                        CircularIconButton(
                            action: {
                                print("Declined \(request.nickname)")
                            },
                            icon: "xmark.circle.fill",
                            gradientColors: [Color.red, Color.orange]
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                )
            }
        }
        .padding()
    }
}

// MARK: - CircularIconButton
struct CircularIconButton: View {
    let action: () -> Void
    let icon: String
    let gradientColors: [Color]

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(gradient: Gradient(colors: gradientColors),
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 1.1 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0.1,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}


// MARK: - Preview
struct MatchRequestView_Previews: PreviewProvider {
    static var previews: some View {
        MatchRequestView(matchRequests: [
            MatchRequest(id: 1, nickname: "Boxer1", weight: 70, height: 175),
            MatchRequest(id: 2, nickname: "Boxer2", weight: 65, height: 180),
            MatchRequest(id: 3, nickname: "Boxer3", weight: 75, height: 170)
        ])
        .background(Color(.systemGroupedBackground))
    }
}
