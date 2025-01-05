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
    @State private var keyboardHeight: CGFloat = 0
    @State private var isViewAppeared = false
    
    // MARK: - Initialization
    init(tpChannel: TPChannel) {
        self.tpChannel = tpChannel
        _delegate = StateObject(wrappedValue: ChatRoomDelegate(channelId: tpChannel.getId()))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !isViewAppeared || !delegate.isInitialized {
                    LoadingView()
                } else if delegate.messages.isEmpty {
                    EmptyMessageView()
                } else {
                    messageList
                }
                
                Divider()
                MessageInputField(text: $messageText, onSend: sendMessage)
                    .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image("profile_placeholder")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        
                        Text(tpChannel.getName() ?? "")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.mainRed)
                    }
                }
            }
        }
        .onAppear {
            isViewAppeared = true
            setupKeyboardNotifications()
            delegate.loadInitialMessages(for: tpChannel)
        }
        .onDisappear {
            cleanupKeyboardNotifications()
        }
    }
    
    // MARK: - UI Components
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(delegate.messages, id: \.self) { message in
                        MessageBubble(message: message)
                            .id(message.getId())
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
            .onChange(of: delegate.messages) { _ in
                scrollToLastMessage()
            }
        }
    }
    
    // MARK: - Methods
    private func scrollToLastMessage() {
        guard let lastMessage = delegate.messages.last else { return }
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring()) {
                scrollProxy?.scrollTo(delegate.messages.last?.getId(), anchor: .bottom)
            }
        }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        self.scrollToBottom()
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
            DispatchQueue.main.async {
                if let message = message {
                    self.delegate.messages.append(message)
                    self.scrollToLastMessage()
                }
            }
        } failure: { (errorCode, error) in
            messageText = currentText
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading messages...")
                .foregroundColor(.gray)
                .padding(.top)
            Spacer()
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
                .padding(10)
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
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let message: TPMessage
    
    private var isMe: Bool {
        message.getUserId() == UserDataManager.shared.getUserData()?.id.toString()
    }
    
    var body: some View {
        HStack {
            if isMe { Spacer() }
            
            Text(message.getText() ?? "")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isMe ? Color.mainRed : Color(.systemGray6))
                .foregroundColor(isMe ? .white : .primary)
                .cornerRadius(20)
            
            if !isMe { Spacer() }
        }
    }
}

// MARK: - Chat Room Delegate
class ChatRoomDelegate: NSObject, TPChannelDelegate, ObservableObject {
    private var channelId: String
    @Published var messages: [TPMessage] = []
    @Published var isInitialized = false
    
    init(channelId: String) {
        self.channelId = channelId
        super.init()
        TalkPlus.sharedInstance()?.add(self, tag: channelId)
    }
    
    deinit {
        TalkPlus.sharedInstance()?.removeChannelDelegate(channelId)
    }
    
    func loadInitialMessages(for channel: TPChannel) {
        let params = TPMessageRetrievalParams(channel: channel)
        params?.orderby = .orderByLatest
        
        TalkPlus.sharedInstance()?.getMessages(params, success: { [weak self] tpMessages, hasNext in
            guard let self = self,
                  let tpMessages = tpMessages else { return }
            
            DispatchQueue.main.async {
                self.messages = Array(tpMessages.reversed())
                self.isInitialized = true
            }
        }, failure: { [weak self] (errorCode, error) in
            DispatchQueue.main.async {
                self?.isInitialized = false
            }
        })
    }
    
    func messageReceived(_ tpChannel: TPChannel, message: TPMessage) {
        guard tpChannel.getId() == channelId else { return }
        
        DispatchQueue.main.async {
            self.messages.append(message)
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

struct EmptyMessageView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("아직 대화가 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
        }
    }
}
