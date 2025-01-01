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
    @State private var showAlert = false
    @State private var errorMessage = ""
    
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
            .alert("저장 실패", isPresented: $showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
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
        
        // 필수 데이터 설정
        session.id = UUID()
        session.date = Date()
        session.punchCount = Int32(punchCount)
        session.duration = highlights.last ?? 0
        
        // 선택적 데이터 설정
        session.memo = memo.isEmpty ? nil : memo
        session.videoURL = videoURL
        session.highlightsData = try? JSONEncoder().encode(highlights)
        
        do {
            if viewContext.hasChanges {
                try viewContext.save()
                print("Session saved successfully")
                presentationMode.wrappedValue.dismiss()
            } else {
                print("No changes to save")
            }
        } catch {
            print("Error saving context: \(error)")
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }
}
