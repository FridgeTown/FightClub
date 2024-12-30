//
//  RecordingView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import AVFoundation

struct RecordingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var recorder = VideoRecorder()
    @State private var isRecording = false
    @State private var showingConfirmation = false
    
    var body: some View {
        ZStack {
            // 카메라 프리뷰
            CameraPreviewView(session: recorder.session)
                .edgesIgnoringSafeArea(.all)
            
            // 사용자 감지 상태 메시지
            if !recorder.userDetected {
                Text("사용자를 인식할 수 없습니다.")
                    .font(.headline)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            // 펀치 카운트
            VStack {
                if isRecording {
                    Text("펀치 횟수: \(recorder.punchCount)")
                        .font(.title)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
                
                // 녹화 컨트롤
                HStack {
                    Spacer()
                    Button(action: toggleRecording) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(isRecording ? .red : .white)
                    }
                    Spacer()
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("녹화", displayMode: .inline)
        .navigationBarBackButtonHidden(isRecording)
        .sheet(isPresented: $showingConfirmation) {
            ConfirmationView(
                videoURL: recorder.videoURL,
                punchCount: recorder.punchCount,
                highlights: recorder.highlights
            )
        }
        .onAppear {
            DispatchQueue.main.async {
                recorder.checkPermissions()
                if recorder.isAuthorized {
                    recorder.startSession()
                }
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                recorder.stopSession()
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            recorder.stopRecording()
            isRecording = false
            showingConfirmation = true
        } else {
            recorder.startRecording()
            isRecording = true
        }
    }
}


struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        
        // 메인 스레드에서 레이어 추가
        DispatchQueue.main.async {
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
                
                if let connection = previewLayer.connection {
                    let currentDevice = UIDevice.current
                    let orientation = currentDevice.orientation
                    
                    if connection.isVideoOrientationSupported {
                        switch orientation {
                        case .portrait:
                            connection.videoOrientation = .portrait
                        case .landscapeRight:
                            connection.videoOrientation = .landscapeLeft
                        case .landscapeLeft:
                            connection.videoOrientation = .landscapeRight
                        case .portraitUpsideDown:
                            connection.videoOrientation = .portraitUpsideDown
                        default:
                            connection.videoOrientation = .portrait
                        }
                    }
                }
            }
        }
    }
}
