//
//  RecordingView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVFoundation
import AVKit
import WatchConnectivity

struct RecordingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var notificationHandler = NotificationHandler()
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var showingConfirmation = false
    @State private var memo: String = ""
    @State private var showingSummary = false
    @State private var recordedVideoURL: URL?
    @State private var isViewAppeared = false
    @State private var showWatchAppAlert = false
    @State private var showPunchEffect = false
    
    var body: some View {
        ZStack {
            if showingSummary {
                RecordingSummaryView(
                    duration: recordingManager.elapsedTime,
                    punchCount: recordingManager.punchCount,
                    videoURL: recordedVideoURL,
                    heartRate: healthKitManager.heartRate,
                    calories: healthKitManager.activeCalories,
                    memo: $memo,
                    onSave: saveRecording,
                    onDiscard: discardRecording
                )
            } else {
                recordingView
            }
            
            // 알림 오버레이 추가
            NotificationOverlay()
            
            // 펀치 효과 오버레이
            if showPunchEffect {
                Color.red
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: showPunchEffect)
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
        .environmentObject(notificationHandler)
        .alert(isPresented: $showWatchAppAlert) {
            Alert(
                title: Text("Watch App Not Installed"),
                message: Text("Please install the Watch App to use this feature."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: recordingManager.punchCount) { newCount in
            // 펀치가 감지될 때마다 효과 표시
            showPunchEffect = true
            
            // 0.2초 후에 효과 제거
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    showPunchEffect = false
                }
            }
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
        if !WCSession.default.isWatchAppInstalled {
            showWatchAppAlert = true
            return
        }
        
        recordingManager.startRecording()
        healthKitManager.startWorkoutSession()
    }
    
    private func stopRecording() {
        recordingManager.stopRecording { url in
            healthKitManager.stopWorkoutSession()
            if let url = url {
                self.recordedVideoURL = url
                self.showingSummary = true
            }
        }
    }
    
    private func saveRecording() {
        let newSession = BoxingSession(context: viewContext)
        
        // 데이터 설정
        newSession.date = Date()
        newSession.duration = recordingManager.elapsedTime
        newSession.punchCount = Int32(recordingManager.punchCount)
        newSession.memo = memo.isEmpty ? nil : memo
        newSession.heartRate = HealthKitManager.shared.heartRate
        newSession.activeCalories = HealthKitManager.shared.activeCalories
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("저장 실패: \(error.localizedDescription)")
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
    let heartRate: Double
    let calories: Double
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
                        
                        // 심박수 카드
                        StatisticCardView(
                            icon: "heart.fill",
                            value: String(format: "%.0f", heartRate),
                            title: "평균 심박수",
                            color: mainRed
                        )
                        
                        // 칼로리 카드
                        StatisticCardView(
                            icon: "flame.fill",
                            value: String(format: "%.0f", calories),
                            title: "소모 칼로리",
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

// 펀치 효과를 위한 애니메이션 수정자
struct PunchEffectModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        Color.red
                            .opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                            .transition(.opacity)
                            .animation(.easeOut(duration: 0.2), value: isActive)
                    }
                }
            )
    }
}


extension View {
    func punchEffect(isActive: Bool) -> some View {
        self.modifier(PunchEffectModifier(isActive: isActive))
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
