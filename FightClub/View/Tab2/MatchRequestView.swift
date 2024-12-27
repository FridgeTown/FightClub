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
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        
                        Image("profile_placeholder") // 프로필 이미지
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    
                    // 사용자 정보
                    VStack(alignment: .leading, spacing: 8) {
                        Text(request.nickname)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            SpecView()
//                            TagView(text: "\(request.weight)kg", color: .green)
//                            TagView(text: "\(request.height)cm", color: .blue)
                        }
                    }
                    
                    Spacer()
                    
                    // 수락/거절 버튼
                    VStack(spacing: 8) {
                        Button(action: {
                            print("Accepted \(request.nickname)")
                        }) {
                            Text("수락")
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(LinearGradient(gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]),
                                                           startPoint: .leading,
                                                           endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                        
                        Button(action: {
                            print("Declined \(request.nickname)")
                        }) {
                            Text("거절")
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(LinearGradient(gradient: Gradient(colors: [Color.red, Color.red.opacity(0.7)]),
                                                           startPoint: .leading,
                                                           endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .gray.opacity(0.2), radius: 8, x: 0, y: 4)
                )
            }
        }
        .padding()
    }
}

// MARK: - SIBAL 

// MARK: - TagView
struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(10)
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
