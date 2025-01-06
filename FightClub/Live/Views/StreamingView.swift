//
//  StreamingView.swift
//  FightClub
//
//  Created by Edward Lee on 1/6/25.
//

import SwiftUI
import LiveKit
import AVFoundation

struct StreamingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var room: Room
    
    var body: some View {
        StreamingViewControllerRepresentable(dismiss: dismiss)
            .ignoresSafeArea()
    }
}

struct StreamingViewControllerRepresentable: UIViewControllerRepresentable {
    let dismiss: DismissAction
    
    func makeUIViewController(context: Context) -> StreamingViewController {
        StreamingViewController(dismiss: dismiss)
    }
    
    func updateUIViewController(_ uiViewController: StreamingViewController, context: Context) {}
}

class StreamingViewController: UIViewController {
    private let dismiss: DismissAction
    private var cameraManager: CameraManager!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    // UI Elements
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.setTitle("CLOSE", for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var guideLineView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.systemPink.cgColor
        view.layer.borderWidth = 2
        return view
    }()
    
    init(dismiss: DismissAction) {
        self.dismiss = dismiss
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if #available(iOS 16.0, *) {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                    interfaceOrientations: .landscapeRight
                )
                windowScene.requestGeometryUpdate(geometryPreferences) { _ in
                    // 에러가 발생하더라도 계속 진행
                }
            }
        }
        
        AppUtility.lockOrientation(.landscapeRight)
        
        // 카메라 시작
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.cameraManager?.startSession()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if #available(iOS 16.0, *) {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                    interfaceOrientations: .portrait
                )
                windowScene.requestGeometryUpdate(geometryPreferences) { _ in
                    // 에러가 발생하더라도 계속 진행
                }
            }
        }
        
        AppUtility.lockOrientation(.portrait)
        
        // 카메라 정지
        cameraManager?.stopSession()
    }
    
    override var shouldAutorotate: Bool {
        false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscapeRight
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }
    
    private func setupCamera() {
        cameraManager = CameraManager()
        cameraManager.requestAccess { [weak self] granted in
            guard granted else { return }
            
            DispatchQueue.main.async {
                self?.setupPreviewLayer()
            }
        }
    }
    
    private func setupPreviewLayer() {
        guard let session = cameraManager?.session else { return }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .landscapeRight
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewLayer.frame = self.view.bounds
            self.view.layer.insertSublayer(self.previewLayer, at: 0)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Add UI elements
        view.addSubview(closeButton)
        view.addSubview(guideLineView)
        
        // Setup constraints
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        guideLineView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            guideLineView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guideLineView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            guideLineView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            guideLineView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }
    
    @objc private func closeTapped() {
        dismiss()
    }
}

class CameraManager {
    var session: AVCaptureSession
    private var currentPosition: AVCaptureDevice.Position = .back
    
    init() {
        self.session = AVCaptureSession()
        self.session.sessionPreset = .hd1920x1080
    }
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupCamera()
                }
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("카메라 설정 오류: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    func switchCamera() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        
        currentPosition = currentPosition == .back ? .front : .back
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("카메라 전환 오류: \(error)")
        }
        
        session.commitConfiguration()
    }
}
