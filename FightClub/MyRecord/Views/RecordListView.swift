//
//  RecordListView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import CoreData
import AVFoundation
import AVKit
import Vision
import Combine

struct RecordListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BoxingSession.date, ascending: false)],
        animation: .default)
    private var sessions: FetchedResults<BoxingSession>
    @State private var showingRecordingView = false
    @State private var selectedSession: BoxingSession?
    @State private var showingVideoPlayer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    HStack {
                        Text("나의 기록")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            showingRecordingView = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.mainRed)
                        }
                    }
                    .padding()
                    .background(Color.black)
                    
                    if sessions.isEmpty {
                        Spacer()
                        RecordEmptyStateView()
                        Spacer()
                    } else {
                        List {
                            ForEach(sessions) { session in
                                RecordCardView(session: session)
                            }
                            .onDelete(perform: deleteItems)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .listStyle(.plain)
                        .background(Color(.background))
                    }
                }
            }
            .sheet(isPresented: $showingRecordingView) {
                RecordingView()
            }
            .fullScreenCover(isPresented: $showingVideoPlayer) {
                if let session = selectedSession,
                   let videoURL = session.videoURL {
                    RecordVideoPlayerView(url: videoURL)
                        .onAppear {
                            print("Video URL: \(videoURL)")
                        }
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { sessions[$0] }.forEach { session in
                // 비디오 파일 삭제
                if let videoURL = session.videoURL {
                    try? FileManager.default.removeItem(at: videoURL)
                }
                viewContext.delete(session)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting record: \(error)")
            }
        }
    }
}

struct RecordCardView: View {
    let session: BoxingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 상단: 날짜와 재생 버튼
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let memo = session.memo, !memo.isEmpty {
                        Text(memo)
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 재생 버튼
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.mainRed)
                    .shadow(color: .black.opacity(0.3), radius: 5)
            }
            
            // 메인 통계
            HStack(spacing: 20) {
                // 펀치 수
                StatBox(
                    value: "\(session.punchCount)",
                    label: "PUNCH",
                    icon: "figure.boxing",
                    gradient: [Color.black.opacity(0.4), Color.black.opacity(0.2)]
                )
                
                // 운동 시간
                StatBox(
                    value: formattedDuration,
                    label: "TIME",
                    icon: "clock",
                    gradient: [Color.black.opacity(0.4), Color.black.opacity(0.2)]
                )
            }
            
            // 워치 데이터가 있는 경우에만 표시
            if hasWatchData {
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.vertical, 8)
                
                // 워치 통계
                HStack(spacing: 16) {
                    // 최고 속도
                    if session.maxPunchSpeed > 0 {
                        WatchStatView(
                            value: String(format: "%.1f", session.maxPunchSpeed),
                            unit: "m/s",
                            label: "최고 속도",
                            icon: "speedometer"
                        )
                    }
                    
                    // 평균 속도
                    if session.avgPunchSpeed > 0 {
                        WatchStatView(
                            value: String(format: "%.1f", session.avgPunchSpeed),
                            unit: "m/s",
                            label: "평균 속도",
                            icon: "gauge"
                        )
                    }
                    
                    // 심박수
                    if session.heartRate > 0 {
                        WatchStatView(
                            value: String(format: "%.0f", session.heartRate),
                            unit: "bpm",
                            label: "심박수",
                            icon: "heart.fill"
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
        .shadow(color: Color.mainRed.opacity(0.2), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.mainRed.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var hasWatchData: Bool {
        return session.heartRate > 0 || session.maxPunchSpeed > 0 || session.avgPunchSpeed > 0
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: session.date ?? Date())
    }
    
    private var formattedDuration: String {
        let duration = Int(session.duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// 메인 통계 박스
struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.mainRed)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(gradient: Gradient(colors: gradient),
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.mainRed.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(1)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }
}

// 워치 통계 뷰
struct WatchStatView: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.mainRed)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
}

struct RecordEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.slash")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)
            
            Text("아직 기록이 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("새로운 운동을 기록해보세요")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding()
    }
}

struct RecordVideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            CustomVideoPlayer(url: url)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: { 
                        dismiss() 
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.showsPlaybackControls = true
        player.play()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
