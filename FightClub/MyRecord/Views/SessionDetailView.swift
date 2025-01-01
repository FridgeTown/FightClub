//
//  SessionDetailView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVKit

struct SessionDetailView: View {
    let session: BoxingSession
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 날짜
                Text(session.date, style: .date)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 운동 통계
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock")
                        Text("운동 시간: \(formatDuration(session.duration))")
                    }
                    
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("총 펀치 횟수: \(session.punchCount)회")
                    }
                }
                .font(.headline)
                
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
}
