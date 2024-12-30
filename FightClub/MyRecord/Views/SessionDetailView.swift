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
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        List {
            Section(header: Text("세션 정보")) {
                HStack {
                    Text("날짜")
                    Spacer()
                    Text(session.date, style: .date)
                }
                
                HStack {
                    Text("총 펀치 횟수")
                    Spacer()
                    Text("\(session.punchCount)회")
                }
                
                HStack {
                    Text("운동 시간")
                    Spacer()
                    Text(String(format: "%.1f분", session.duration / 60))
                }
            }
            
            if let memo = session.memo, !memo.isEmpty {
                Section(header: Text("메모")) {
                    Text(memo)
                }
            }
            
            if let url = session.videoURL {
                Section(header: Text("영상")) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 200)
                    
                    if !session.highlights.isEmpty {
                        ForEach(session.highlights, id: \.self) { timestamp in
                            Button(action: {
                                seekToHighlight(timestamp)
                            }) {
                                HStack {
                                    Image(systemName: "star.fill")
                                    Text("하이라이트 \(formatTime(timestamp))")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("세션 상세")
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func seekToHighlight(_ time: TimeInterval) {
        guard let url = session.videoURL else { return }
        
        if player == nil {
            player = AVPlayer(url: url)
        }
        
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        player?.play()
        isPlaying = true
    }
}
