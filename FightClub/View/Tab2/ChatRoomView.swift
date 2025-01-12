import SwiftUI
import TalkPlus
import KeychainAccess

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
    @State private var showStreamingView = false
    
    // LiveKit Context 추가
    @StateObject private var roomContext: RoomContext
    @StateObject private var appContext: AppContext
    
    // MARK: - Initialization
    init(tpChannel: TPChannel) {
        self.tpChannel = tpChannel
        _delegate = StateObject(wrappedValue: ChatRoomDelegate(channelId: tpChannel.getId()))
        
        // LiveKit Context 초기화
        let preferences = Preferences()
        let keychain = Keychain(service: "com.fightclub.app")
        let store = ValueStore(store: keychain, 
                             key: "preferences",
                             default: preferences)
        _roomContext = StateObject(wrappedValue: RoomContext(store: store))
        _appContext = StateObject(wrappedValue: AppContext(store: store))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
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
                            print("ChatRoomView - Dismissing")
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.mainRed)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            setupLandscapeOrientation()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showStreamingView = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "video.fill")
                                Text("Live")
                            }
                            .foregroundColor(Color.mainRed)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showStreamingView, onDismiss: {
                setupPortraitOrientation()
            }) {
                StreamingView(channelId: tpChannel.getId())
                    .environmentObject(roomContext)
                    .environmentObject(appContext)
            }
        }
        .task {
            print("ChatRoomView - Task started")
            isViewAppeared = true
            setupKeyboardNotifications()
            print("ChatRoomView - Loading initial messages")
            delegate.loadInitialMessages(for: tpChannel)
        }
        .onDisappear {
            print("ChatRoomView - Disappearing")
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
                TalkPlus.sharedInstance()?.mark(asRead: tpChannel,
                                                success: { tpChannel in
                    // SUCCESS
                }, failure: { (errorCode, error) in
                    // FAILURE
                })
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
    
    private func setupLandscapeOrientation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                if error != nil {
                    print("Failed to update geometry: \(error.localizedDescription ?? "")")
                }
            }
        }
        AppDelegate.orientationLock = .landscape
    }
    
    private func setupPortraitOrientation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                if error != nil {
                    print("Failed to update geometry: \(error.localizedDescription ?? "")")
                }
            }
        }
        AppDelegate.orientationLock = .all
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("불러오는 중...")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
        print("ChatRoomDelegate - Initializing with channel ID: \(channelId)")
        self.channelId = channelId
        super.init()
        print("ChatRoomDelegate - Adding delegate")
        TalkPlus.sharedInstance()?.add(self, tag: channelId)
    }
    
    deinit {
        print("ChatRoomDelegate - Deinitializing")
        TalkPlus.sharedInstance()?.removeChannelDelegate(channelId)
    }
    
    func loadInitialMessages(for channel: TPChannel) {
        print("ChatRoomDelegate - Loading messages for channel: \(channel.getId())")
        let params = TPMessageRetrievalParams(channel: channel)
        params?.orderby = .orderByLatest
        
        print("ChatRoomDelegate - Calling TalkPlus.getMessages")
        TalkPlus.sharedInstance()?.getMessages(params, success: { [weak self] tpMessages, hasNext in
            print("ChatRoomDelegate - getMessages success callback")
            guard let self = self else {
                print("ChatRoomDelegate - Self is nil")
                return
            }
            
            guard let tpMessages = tpMessages else {
                print("ChatRoomDelegate - Messages is nil")
                DispatchQueue.main.async {
                    self.isInitialized = false
                }
                return
            }
            
            print("ChatRoomDelegate - Successfully loaded \(tpMessages.count) messages")
            DispatchQueue.main.async {
                self.messages = Array(tpMessages.reversed())
                self.isInitialized = true
                print("ChatRoomDelegate - Updated messages and initialized state")
            }
        }, failure: { [weak self] (errorCode, error) in
            print("ChatRoomDelegate - Failed to load messages: \(errorCode), \(String(describing: error))")
            DispatchQueue.main.async {
                self?.isInitialized = false
            }
        })
    }
    
    func messageReceived(_ tpChannel: TPChannel, message: TPMessage) {
        guard tpChannel.getId() == channelId else {
            print("ChatRoomDelegate - Received message for different channel")
            return
        }
        
        print("ChatRoomDelegate - Received new message")
        DispatchQueue.main.async {
            self.messages.append(message)
            print("ChatRoomDelegate - Added new message to list")
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
            Spacer()
            
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("아직 대화가 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("첫 메시지를 보내보세요!")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
