//
//  ConfirmationView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVKit

struct ConfirmationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let videoURL: URL?
    let punchCount: Int
    let highlights: [TimeInterval]
    
    @State private var memo: String = ""
    @State private var showingPlayer = false
    @State private var selectedHighlight: TimeInterval?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("운동 결과")) {
                    HStack {
                        Text("총 펀치 횟수")
                        Spacer()
                        Text("\(punchCount)회")
                    }
                }
                
                Section(header: Text("영상")) {
                    if let url = videoURL {
                        Button(action: { showingPlayer = true }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("녹화 영상 보기")
                            }
                        }
                        
                        if !highlights.isEmpty {
                            ForEach(highlights, id: \.self) { timestamp in
                                Button(action: {
                                    selectedHighlight = timestamp
                                    showingPlayer = true
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
                
                Section(header: Text("메모")) {
                    TextEditor(text: $memo)
                        .frame(height: 100)
                }
            }
            .navigationTitle("운동 확인")
            .navigationBarItems(
                leading: Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("저장") {
                    saveSession()
                }
            )
            .sheet(isPresented: $showingPlayer) {
                if let url = videoURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .onAppear {
                            if let timestamp = selectedHighlight {
                                seekToTime(timestamp)
                            }
                        }
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func seekToTime(_ time: TimeInterval) {
        // 비디오 플레이어의 시간 이동
    }
    
    private func saveSession() {
        let session = BoxingSession(context: viewContext)
        session.punchCount = Int32(punchCount)
        session.memo = memo
        session.videoURL = videoURL
        session.highlights = highlights
        session.duration = highlights.last ?? 0
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving session: \(error)")
        }
    }
}
