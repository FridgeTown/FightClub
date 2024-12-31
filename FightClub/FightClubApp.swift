//
//  FightClubApp.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import SwiftUI
import GoogleSignIn
import CoreData
import Firebase
import UserNotifications
import TalkPlus

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    private var pendingFCMToken: String?
    private var apnsTokenReceived = false
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 파이어베이스 설정
        FirebaseApp.configure()
        
        // 앱 실행 시 사용자에게 알림 허용 권한을 받음
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        // UNUserNotificationCenterDelegate를 구현한 메서드를 실행
        application.registerForRemoteNotifications()
        
        // 파이어베이스 Messaging 설정
        Messaging.messaging().delegate = self
        
        // TalkPlus 초기화
        TalkPlus.sharedInstance()?.initWithAppId("abc3aa8d-947b-4549-a793-7c79dcd57333")
        
        // 로그인 노티피케이션 옵저버 추가
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLogin),
            name: Notification.Name("UserDidLogin"),
            object: nil
        )
        
        return true
    }
    
    @objc private func handleUserLogin() {
        // 로그인 성공 시 보류 중인 FCM 토큰이 있다면 등록
        if let pendingToken = pendingFCMToken {
            registerFCMToken(fcmToken: pendingToken)
        } else {
            // 보류 중인 토큰이 없다면 새로 요청
            requestFCMToken()
        }
    }
    
    func registerFCMToken(fcmToken: String) {
        // 사용자가 로그인되어 있는지 확인
        guard UserDataManager.shared.getUserData() != nil else {
            print("사용자가 로그인되어 있지 않습니다. FCM 토큰 등록을 보류합니다.")
            pendingFCMToken = fcmToken
            return
        }
        
        guard let talkplus = TalkPlus.sharedInstance() else {
            print("TalkPlus not initialized")
            return
        }
        
        talkplus.registerFCMToken(fcmToken) {
            print("fcmToken register success")
            self.pendingFCMToken = nil
        } failure: { errorCode, error in
            print("fcmToken register failure: code \(errorCode), error: \(String(describing: error))")
            // 실패 시 토큰 보관
            self.pendingFCMToken = fcmToken
        }
    }
    
    private func requestFCMToken() {
            guard apnsTokenReceived else {
                print("APNS 토큰이 아직 수신되지 않았습니다.")
                return
            }
            
            Messaging.messaging().token { [weak self] token, error in
                guard let token = token else {
                    if let error = error {
                        print("FCM 토큰 요청 실패: \(error)")
                    }
                    return
                }
                print("FCM 토큰 요청 성공: \(token)")
                
                // UserDataManager를 통해 로그인 상태 확인
                if UserDataManager.shared.getUserData() != nil {
                    self?.registerFCMToken(fcmToken: token)
                } else {
                    self?.pendingFCMToken = token
                    print("사용자가 로그인하지 않은 상태입니다. FCM 토큰을 저장해두었다가 로그인 후 등록합니다.")
                }
            }
        }
        
        // APNS 토큰 수신 시 호출되는 메서드
        func application(_ application: UIApplication,
                        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            print("APNS 토큰 수신: \(deviceToken)")
            Messaging.messaging().apnsToken = deviceToken
            apnsTokenReceived = true
            
            // APNS 토큰을 받은 후 FCM 토큰 요청
            requestFCMToken()
        }
        
        // FCM 토큰 갱신 시 호출되는 메서드
        func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
            print("Firebase 토큰 갱신: \(String(describing: fcmToken))")
            
            if let token = fcmToken {
                if UserDataManager.shared.getUserData() != nil {
                    registerFCMToken(fcmToken: token)
                } else {
                    pendingFCMToken = token
                }
            }
        }
}

@main
struct FightClubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let persistenceController = PersistenceController.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// CoreData 관리를 위한 컨트롤러
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "BoxingSession")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("CoreData store failed to load: \(error.localizedDescription)")
            }
        }
        
        // 자동 저장 설정
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
