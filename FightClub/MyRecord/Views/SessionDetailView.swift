//
//  SessionDetailView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVKit
import WatchConnectivity

struct SessionDetailView: View {
    let session: BoxingSession
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 날짜
                Text(session.date, style: .date)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 운동 통계와 건강 데이터를 함께 표시
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock")
                        Text("운동 시간: \(formatDuration(session.duration))")
                    }
                    
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("총 펀치 횟수: \(session.punchCount)회")
                    }
                    
                    // 건강 데이터는 값이 있을 때만 표시
                    if session.heartRate > 0 || session.activeCalories > 0 {
                        if session.heartRate > 0 {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                Text("평균 심박수: \(Int(session.heartRate))bpm")
                            }
                        }
                        
                        if session.activeCalories > 0 {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("소모 칼로리: \(Int(session.activeCalories))kcal")
                            }
                        }
                    } else {
                        // 건강 데이터가 없을 때 메시지
                        HStack {
                            Image(systemName: "applewatch")
                                .foregroundColor(.gray)
                            Text("Apple Watch로 더 자세한 운동 데이터를 기록해보세요")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .font(.headline)
                
                // 운동 통계 다음에 건강 데이터 표시 추가
                healthMetrics
                
                // 비디오 재생
                if let _ = session.videoURL,
                   let videoURL = session.videoURL {
                    VideoPlayer(url: videoURL)
                        .frame(height: 200)
                        .cornerRadius(10)
                }
                
                // 메모
                if let memo = session.memo {
                    VStack(alignment: .leading) {
                        Text("메모")
                            .font(.headline)
                        Text(memo)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("운동 기록")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)분 \(seconds)초"
    }
    
    private var healthMetrics: some View {
        VStack(spacing: 16) {
            let session = WCSession.default
            if !session.isWatchAppInstalled {
                Text("더 자세한 운동 데이터를 보려면\nApple Watch에 앱을 설치해주세요.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // 건강 데이터 표시
                HStack(spacing: 20) {
                    // 심박수
                    VStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(Int(self.session.heartRate))bpm")
                            .font(.headline)
                        Text("평균 심박수")
                            .font(.caption)
                    }
                    
                    // 칼로리
                    VStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(Int(self.session.activeCalories))kcal")
                            .font(.headline)
                        Text("소모 칼로리")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
}
