import SwiftUI

struct NotificationOverlay: View {
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if notificationService.showNotification,
                   let notification = notificationService.currentNotification {
                    NotificationBanner(
                        event: notification,
                        isPresented: $notificationService.showNotification
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0 + 16)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: notificationService.showNotification)
        }
    }
} 