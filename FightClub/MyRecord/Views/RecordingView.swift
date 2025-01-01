//
//  RecordingView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVFoundation
import AVKit

struct RecordingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var recordingManager = RecordingManager()
    @State private var showingConfirmation = false
    @State private var memo: String = ""
    @State private var showingSummary = false
    @State private var recordedVideoURL: URL?
    @State private var isViewAppeared = false
    
    var body: some View {
        ZStack {
            if showingSummary {
                RecordingSummaryView(
                    duration: recordingManager.elapsedTime,
                    punchCount: recordingManager.punchCount,
                    videoURL: recordedVideoURL,
                    memo: $memo,
                    onSave: saveRecording,
                    onDiscard: discardRecording
                )
            } else {
                recordingView
            }
        }
        .statusBar(hidden: true)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            print("RecordingView appeared")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                recordingManager.startCamera()
                isViewAppeared = true
            }
        }
        .onDisappear {
            print("RecordingView disappeared")
            recordingManager.stopCamera()
            isViewAppeared = false
        }
    }
    
    private var recordingView: some View {
        ZStack {
            if recordingManager.isCameraAuthorized {
                // 카메라 프리뷰
                if isViewAppeared, let previewLayer = recordingManager.getPreviewLayer() {
                    CameraPreviewView(previewLayer: previewLayer)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                }
                
                // 오버레이 UI
                VStack {
                    // 상단 바
                    HStack {
                        Button(action: {
                            showingConfirmation = true
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        Text("\(recordingManager.punchCount) 펀치")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .background(Color.black.opacity(0.5))
                    
                    Spacer()
                    
                    // 하단 컨트롤
                    VStack {
                        Text(timeString(from: recordingManager.elapsedTime))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom)
                        
                        // 녹화 버튼
                        Button(action: {
                            if recordingManager.isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            Circle()
                                .fill(recordingManager.isRecording ? Color.red : Color.white)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                )
                        }
                    }
                    .padding(.bottom, 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            } else {
                // 카메라 권한이 없는 경우
                VStack {
                    Text("카메라 접근 권한이 필요합니다")
                        .font(.headline)
                    Text("설정 앱에서 카메라 권한을 허용해주세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("설정으로 이동") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top)
                }
                .padding()
            }
        }
        .alert(isPresented: $showingConfirmation) {
            Alert(
                title: Text("녹화 종료"),
                message: Text("녹화를 종료하시겠습니까?"),
                primaryButton: .destructive(Text("종료")) {
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("취소"))
            )
        }
    }
    
    private func startRecording() {
        recordingManager.startRecording()
    }
    
    private func stopRecording() {
        recordingManager.stopRecording { url in
            self.recordedVideoURL = url
            self.showingSummary = true
        }
    }
    
    private func saveRecording() {
        // CoreData에 세션 저장
        let newSession = BoxingSession(context: viewContext)
        newSession.date = Date()
        newSession.duration = recordingManager.elapsedTime
        newSession.punchCount = Int32(recordingManager.punchCount)
        newSession.memo = memo.isEmpty ? nil : memo
        if let videoURL = recordedVideoURL {
            // 비디오 URL 저장 로직 추가
            newSession.videoURL = videoURL
        }
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving session: \(error)")
        }
    }
    
    private func discardRecording() {
        // 녹화된 비디오 삭제
        if let url = recordedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RecordingSummaryView: View {
    let duration: TimeInterval
    let punchCount: Int
    let videoURL: URL?
    @Binding var memo: String
    let onSave: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("운동 요약")
                    .font(.title)
                    .fontWeight(.bold)
                
                // 운동 통계
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock")
                        Text("운동 시간: \(formatDuration(duration))")
                    }
                    
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("총 펀치 횟수: \(punchCount)회")
                    }
                }
                .font(.headline)
                
                // 비디오 미리보기
                if let url = videoURL {
                    VideoPlayer(url: url)
                        .frame(height: 200)
                        .cornerRadius(10)
                }
                
                // 메모 입력
                TextField("메모 입력...", text: $memo)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // 버튼
                HStack(spacing: 20) {
                    Button(action: onDiscard) {
                        Text("삭제")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onSave) {
                        Text("저장")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)분 \(seconds)초"
    }
}

struct VideoPlayer: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    class PreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                if let layer = previewLayer {
                    self.layer.addSublayer(layer)
                    layer.frame = self.bounds
                }
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
    
    func makeUIView(context: Context) -> PreviewUIView {
        print("Creating camera preview view")
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer = previewLayer
        print("Added preview layer to view")
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        print("Updating preview view frame: \(uiView.frame)")
        uiView.setNeedsLayout()
    }
}

//// MARK: - Preview Provider
//#if DEBUG
//struct CameraPreviewView_Previews: PreviewProvider {
//    static var previews: some View {
//        CameraPreviewView(previewLayer: nil)
//    }
//}
//
//extension RecordingView {
//    var navigationBarHidden: some View {
//        self.navigationBarHidden(true)
//    }
//}
//#endif
