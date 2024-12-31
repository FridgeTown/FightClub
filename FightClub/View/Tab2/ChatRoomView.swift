import SwiftUI
import TalkPlus

// MARK: - Main View
struct ChatRoomView: View {
    // MARK: - Properties
    let tpChannel: TPChannel
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @StateObject private var delegate: ChatRoomDelegate
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var lastMessageId: String? = nil
    @State private var keyboardHeight: CGFloat = 0
    
    // MARK: - Initialization
    init(tpChannel: TPChannel) {
        self.tpChannel = tpChannel
        _delegate = StateObject(wrappedValue: ChatRoomDelegate(channelId: tpChannel.getId()))
        // List 스타일 초기화
        UITableView.appearance().backgroundColor = .clear
        UITableView.appearance().separatorStyle = .none
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ChatNavigationBar(
                userName: tpChannel.getName() ?? "",
                onClose: { dismiss() }
            )
            
            messageList
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Divider()
                        MessageInputField(text: $messageText, onSend: sendMessage)
                    }
                    .background(Color(.systemBackground))
                    .padding(.bottom, 0)
                }
        }
        .background(Color(.systemBackground))
        .onAppear {
            setupKeyboardNotifications()
            setupChat()
        }
        .onDisappear {
            cleanupKeyboardNotifications()
            cleanupChat()
        }
    }
    
    // SafeAreaInsets를 저장하기 위한 PreferenceKey 추가
    private struct SafeAreaInsetsKey: PreferenceKey {
        static var defaultValue: EdgeInsets = .init()
        
        static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
            value = nextValue()
        }
    }
    
    // MARK: - UI Components
    private var messageList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(delegate.messages, id: \.self) { message in
                    MessageBubble(message: message)
                        .id(message.getId())
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                }
                // 스크롤 앵커용 빈 뷰 최소화
                Color.clear
                    .frame(height: 0)
                    .id("bottom")
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
            }
            .listStyle(PlainListStyle())
            // 모든 방향의 패딩 제거
            .padding(0)
            // contentInset 조정
            .environment(\.defaultMinListRowHeight, 0)
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
            .onChange(of: delegate.messages) { _ in
                scrollToLastMessage()
            }
            // 키보드 알림 구독
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                scrollToLastMessage()
            }
            // 새 메시지 알림 구독
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NewMessageReceived"))) { _ in
                scrollToLastMessage()
            }
        }
    }
    
    // MARK: - Methods
    private func scrollToLastMessage() {
        guard let lastMessage = delegate.messages.last else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring()) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
    
    private func scrollToBottom(force: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring()) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
    
    private func setupChat() {
        TalkPlus.sharedInstance()?.add(delegate, tag: "ChatRoom")
        getMessages()
    }
    
    private func cleanupChat() {
        TalkPlus.sharedInstance()?.removeChannelDelegate("ChatRoom")
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
               let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                withAnimation(.easeOut(duration: duration)) {
                    self.keyboardHeight = keyboardFrame.height
                    // 키보드 애니메이션 완료 후 스크롤
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        self.scrollToBottom(force: true)
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                withAnimation(.easeOut(duration: duration)) {
                    self.keyboardHeight = 0
                }
            }
        }
    }
    
    private func cleanupKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let params = TPMessageSendParams(contentType: .text,
                                       messageType: .text,
                                       channel: tpChannel)
        params?.textMessage = messageText
        let currentText = messageText
        messageText = ""
        
        TalkPlus.sharedInstance()?.sendMessage(params) { message in
            print("메시지 전송 성공")
            DispatchQueue.main.async {
                if let message = message {
                    self.delegate.messages.append(message)
                    self.scrollToLastMessage()
                }
            }
        } failure: { (errorCode, error) in
            print("메시지 전송 실패: \(errorCode), \(String(describing: error))")
            messageText = currentText
        }
    }
    
    private func getMessages() {
            let params = TPMessageRetrievalParams(channel: tpChannel)
            params?.orderby = .orderByLatest
            
            TalkPlus.sharedInstance()?.getMessages(params, success: { tpMessages, hasNext in
                guard let tpMessages = tpMessages else { return }
                
                DispatchQueue.main.async {
                    delegate.messages = Array(tpMessages.reversed())
                    // 메시지 로드 후 스크롤
                    if let _ = delegate.messages.last {
                        lastMessageId = tpChannel.getLastMessage().getId()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                scrollToBottom()
                            }
                        }
                    }
                }
            }, failure: { (errorCode, error) in
                print("메시지 가져오기 실패: \(errorCode), \(String(describing: error))")
            })
        }
}

// MARK: - Navigation Bar Component
struct ChatNavigationBar: View {
    // MARK: - Properties
    let userName: String
    let onClose: () -> Void
    
    // MARK: - Body
    var body: some View {
        HStack {
            backButton
            userInfo
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
    }
    
    // MARK: - UI Components
    private var backButton: some View {
        Button(action: onClose) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.mainRed)
        }
        .padding(.leading)
    }
    
    private var userInfo: some View {
        HStack {
            Image("profile_placeholder")
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            
            Text(userName)
                .font(.headline)
        }
    }
}

// MARK: - Message Input Component
struct MessageInputField: View {
    @Binding var text: String
    let onSend: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("메시지를 입력하세요", text: $text)
                .padding(10) // 패딩 감소
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !text.isEmpty {
                        onSend()
                    }
                }
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(text.isEmpty ? .gray : Color.mainRed)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 2) // 상하 패딩 최소화
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    // MARK: - Properties
    let message: TPMessage
    
    private var isMe: Bool {
        message.getUserId() == UserDataManager.shared.getUserData()?.id.toString()
    }
    
    // MARK: - Body
    var body: some View {
        HStack {
            if isMe { Spacer() }
            
            Text(message.getText() ?? "")
                .padding(.horizontal, 16)
                .padding(.vertical, 8) // 수직 패딩 감소
                .background(isMe ? Color.mainRed : Color(.systemGray6))
                .foregroundColor(isMe ? .white : .primary)
                .cornerRadius(20)
            
            if !isMe { Spacer() }
        }
        .padding(.vertical, 1) // 메시지 간 간격 최소화
    }
}

// MARK: - Chat Room Delegate
class ChatRoomDelegate: NSObject, TPChannelDelegate, ObservableObject {
    // MARK: - Properties
    private var channelId: String
    @Published var messages: [TPMessage] = []
    
    // MARK: - Initialization
    init(channelId: String) {
        self.channelId = channelId
        super.init()
    }
    
    // MARK: - TPChannelDelegate Methods
    func messageReceived(_ tpChannel: TPChannel, message: TPMessage) {
        guard tpChannel.getId() == channelId else { return }
        
        DispatchQueue.main.async {
            self.messages.append(message)
            // 새 메시지가 추가된 후 스크롤
            NotificationCenter.default.post(
                name: Notification.Name("NewMessageReceived"),
                object: nil
            )
        }
    }
    
    // Required delegate methods
    func memberAdded(_ tpChannel: TPChannel, users: [TPMember]) {}
    func memberLeft(_ tpChannel: TPChannel, users: [TPMember]) {}
    func messageDeleted(_ tpChannel: TPChannel, message: TPMessage) {}
    func channelAdded(_ tpChannel: TPChannel) {}
    func channelChanged(_ tpChannel: TPChannel) {}
    func channelRemoved(_ tpChannel: TPChannel) {}
    func memberMuted(_ tpChannel: TPChannel, users: [TPMember]) {}
    func memberUnmuted(_ tpChannel: TPChannel, users: [TPMember]) {}
    func memberBanned(_ tpChannel: TPChannel, users: [TPMember]) {}
    func memberUnbanned(_ tpChannel: TPChannel, users: [TPMember]) {}
    
    // Public channel methods
    func publicMemberAdded(_ tpChannel: TPChannel!, users: [TPMember]!) {}
    func publicMemberLeft(_ tpChannel: TPChannel!, users: [TPMember]!) {}
    func publicChannelAdded(_ tpChannel: TPChannel!) {}
    func publicChannelChanged(_ tpChannel: TPChannel!) {}
    func publicChannelRemoved(_ tpChannel: TPChannel!) {}
}
