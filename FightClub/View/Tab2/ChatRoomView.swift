import SwiftUI

struct ChatRoomView: View {
    let chat: Chat
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 네비게이션 바
            ChatNavigationBar(userName: chat.userName, onClose: { dismiss() })
            
            // 메시지 목록
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sampleMessages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            
            // 메시지 입력
            MessageInputField(text: $messageText) {
                sendMessage()
            }
        }
        .onAppear {
            // SendBird 연결 및 메시지 로드 로직 추가 예정
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        // SendBird 메시지 전송 로직 추가 예정
        messageText = ""
    }
}

struct ChatNavigationBar: View {
    let userName: String
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.mainRed)
            }
            .padding(.leading)
            
            Image("profile_placeholder")
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            
            Text(userName)
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
    }
}

struct MessageInputField: View {
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("메시지를 입력하세요", text: $text)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(text.isEmpty ? .gray : Color.mainRed)
            }
            .disabled(text.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: -2)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isMe {
                Spacer()
            }
            
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.isMe ? Color.mainRed : Color(.systemGray6))
                .foregroundColor(message.isMe ? .white : .primary)
                .cornerRadius(20)
            
            if !message.isMe {
                Spacer()
            }
        }
    }
}

// MARK: - Models
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isMe: Bool
    let timestamp: Date
}

// MARK: - Sample Data
let sampleMessages = [
    ChatMessage(content: "안녕하세요! 오늘 스파링 어떠셨나요?", isMe: false, timestamp: Date()),
    ChatMessage(content: "정말 좋은 경기였습니다!", isMe: true, timestamp: Date()),
    ChatMessage(content: "다음에 또 스파링 하시죠!", isMe: false, timestamp: Date()),
    ChatMessage(content: "네, 좋습니다! 다음 주에 시간 되시나요?", isMe: true, timestamp: Date())
]

// MARK: - Preview
struct ChatRoomView_Previews: PreviewProvider {
    static var previews: some View {
        ChatRoomView(chat: Chat(id: 1, userName: "Boxer Kim", lastMessage: "안녕하세요!"))
    }
} 