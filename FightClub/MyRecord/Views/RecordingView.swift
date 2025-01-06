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
                VStack(spacing: 0) {
                    // 상단 바
                    TopBarView(
                        punchCount: recordingManager.punchCount,
                        onClose: { showingConfirmation = true }
                    )
                    
                    Spacer()
                    
                    // 하단 컨트롤
                    BottomControlView(
                        elapsedTime: recordingManager.elapsedTime,
                        isRecording: recordingManager.isRecording,
                        onRecordingToggle: {
                            if recordingManager.isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }
                    )
                }
            } else {
                // 카메라 권한이 없는 경우
                CameraPermissionView()
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
            if let url = url {
                self.recordedVideoURL = url
                self.showingSummary = true
            } else {
                print("Error: Failed to get video URL")
                // 실패 시에도 summary 화면으로 전환하여 사용자가 선택할 수 있게 함
                self.showingSummary = true
            }
        }
    }
    
    private func saveRecording() {
        guard let videoURL = recordedVideoURL else {
            print("Error: No video URL available")
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        // 비디오 파일을 Documents 디렉토리로 이동
        let fileManager = FileManager.default
        do {
            let documentsPath = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let fileName = "boxing_session_\(Date().timeIntervalSince1970).mov"
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            // 이미 같은 이름의 파일이 있다면 삭제
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // 비디오 파일 복사 (이동 대신 복사를 사용)
            try fileManager.copyItem(at: videoURL, to: destinationURL)
            
            // CoreData에 세션 저장
            let newSession = BoxingSession(context: viewContext)
            newSession.id = UUID()
            newSession.date = Date()
            newSession.duration = recordingManager.elapsedTime
            newSession.punchCount = Int32(recordingManager.punchCount)
            newSession.memo = memo.isEmpty ? nil : memo
            newSession.videoURL = destinationURL
            
            try viewContext.save()
            print("Session saved successfully")
            
            // 원본 파일 삭제
            try? fileManager.removeItem(at: videoURL)
            
            // 저장 성공 후 뷰 닫기
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
            
        } catch {
            print("Error saving session: \(error.localizedDescription)")
            // 에러 발생 시 임시 파일 정리
            try? fileManager.removeItem(at: videoURL)
            
            // 에러 상황에서도 뷰는 닫아줌
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
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
    
    private let mainRed = Color("mainRed")
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // 헤더
                    Text("운동 요약")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 24)
                    
                    // 운동 통계 카드
                    HStack(spacing: 20) {
                        // 시간 카드
                        StatisticCardView(
                            icon: "clock.fill",
                            value: formatDuration(duration),
                            title: "운동 시간",
                            color: mainRed
                        )
                        
                        // 펀치 카드
                        StatisticCardView(
                            icon: "hand.raised.fill",
                            value: "\(punchCount)",
                            title: "총 펀치",
                            color: mainRed
                        )
                    }
                    .padding(.horizontal)
                    
                    // 비디오 미리보기
                    if let url = videoURL {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("운동 영상")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VideoPlayer(url: url)
                                .frame(height: 250)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                    }
                    
                    // 메모 입력
                    VStack(alignment: .leading, spacing: 12) {
                        Text("메모")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("운동에 대한 메모를 입력하세요...", text: $memo)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // 버튼
                    HStack(spacing: 20) {
                        Button(action: onDiscard) {
                            HStack {
                                Image(systemName: "trash")
                                Text("삭제")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.3))
                            )
                        }
                        
                        Button(action: onSave) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("저장")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(mainRed)
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct StatisticCardView: View {
    let icon: String
    let value: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            // 아이콘
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )
            
            // 값
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            // 제목
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
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

// MARK: - Supporting Views
struct TopBarView: View {
    let punchCount: Int
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                Text("\(punchCount)")
                    .font(.system(size: 24, weight: .bold))
                Text("펀치")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.trailing)
        }
        .padding(.top, 48)
    }
}

struct BottomControlView: View {
    let elapsedTime: TimeInterval
    let isRecording: Bool
    let onRecordingToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // 타이머
            Text(timeString(from: elapsedTime))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            
            // 녹화 버튼
            Button(action: onRecordingToggle) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.white)
                        .frame(width: 84, height: 84)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    
                    if isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 74, height: 74)
                    }
                }
            }
            .padding(.bottom, 50)
        }
        .background(
            LinearGradient(
                gradient: Gradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.7)
                    ]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CameraPermissionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("카메라 접근 권한이 필요합니다")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("설정 앱에서 카메라 권한을 허용해주세요")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("설정으로 이동")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 5)
            }
        }
        .padding()
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
