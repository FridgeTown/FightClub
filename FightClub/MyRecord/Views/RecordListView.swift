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
                                    .listRowBackground(Color.black)
                                    .listRowInsets(EdgeInsets())
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        selectedSession = session
                                        showingVideoPlayer = true
                                    }
                            }
                            .onDelete(perform: deleteItems)
                        }
                        .listStyle(PlainListStyle())
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let memo = session.memo, !memo.isEmpty {
                        Text(memo)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.mainRed)
            }
            
            HStack(spacing: 20) {
                StatisticView(
                    icon: "figure.boxing",
                    value: "\(session.punchCount)",
                    label: "펀치 수"
                )
                
                StatisticView(
                    icon: "clock",
                    value: formattedDuration,
                    label: "운동 시간"
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
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

struct StatisticView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.mainRed)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
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
