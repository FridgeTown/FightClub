//
//  RecordingView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVFoundation

struct RecordingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var recordingManager: RecordingManager
    @State private var showingConfirmation = false
    @State private var memo: String = ""
    
    var body: some View {
        ZStack {
            if recordingManager.isCameraAuthorized {
                // 카메라 프리뷰
                CameraPreviewView(previewLayer: recordingManager.getPreviewLayer())
                    .edgesIgnoringSafeArea(.all)
                
                // 오버레이 UI
                VStack {
                    // 상단 정보
                    HStack {
                        Text(timeString(from: recordingManager.elapsedTime))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(recordingManager.punchCount) 펀치")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    
                    Spacer()
                    
                    // 하단 컨트롤
                    VStack(spacing: 20) {
                        // 메모 입력
                        TextField("메모 입력...", text: $memo)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        // 녹화 컨트롤
                        HStack(spacing: 40) {
                            // 취소 버튼
                            Button(action: {
                                showingConfirmation = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.red)
                            }
                            
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
                        .padding(.bottom, 30)
                    }
                    .background(Color.black.opacity(0.5))
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
                    stopRecording()
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
        recordingManager.stopRecording()
        
        // CoreData에 세션 저장
        let newSession = BoxingSession(context: viewContext)
        newSession.date = Date()
        newSession.duration = recordingManager.elapsedTime
        newSession.punchCount = Int32(recordingManager.punchCount)
        newSession.memo = memo.isEmpty ? nil : memo
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving session: \(error)")
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        view.backgroundColor = .black
        
        guard let previewLayer = previewLayer else { 
            print("No preview layer available")
            return view 
        }
        
        // 메인 스레드에서 레이어 설정
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = previewLayer else { return }
        
        // 메인 스레드에서 업데이트
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            
            previewLayer.frame = uiView.bounds
            
            if let connection = previewLayer.connection {
                let orientation = UIDevice.current.orientation
                let videoOrientation: AVCaptureVideoOrientation
                
                switch orientation {
                case .portrait:
                    videoOrientation = .portrait
                case .landscapeLeft:
                    videoOrientation = .landscapeRight
                case .landscapeRight:
                    videoOrientation = .landscapeLeft
                case .portraitUpsideDown:
                    videoOrientation = .portraitUpsideDown
                default:
                    videoOrientation = .portrait
                }
                
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = videoOrientation
                }
            }
            
            CATransaction.commit()
        }
    }
}
