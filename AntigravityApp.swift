import SwiftUI
import WebKit
import AVFoundation
import Speech
import AuthenticationServices
import SafariServices

@main
struct AntigravityRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .edgesIgnoringSafeArea(.all)
        }
    }
}

// MARK: - Audio Recorder & Speech Helper
class VoiceSpeechManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var showVoiceSheet = false
    
    private var audioRecorder: AVAudioRecorder?
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    func requestPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
    
    func startSpeechToText(onUpdate: @escaping (String) -> Void) {
        requestPermissions()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    let text = result.bestTranscription.formattedString
                    self.recognizedText = text
                    onUpdate(text)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopSpeechToText()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine start error: \(error)")
        }
    }
    
    func stopSpeechToText() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}

// MARK: - Safari Passkey Login Sheet
struct SafariPasskeyLoginView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.dismissButtonStyle = .done
        safariVC.delegate = context.coordinator
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var parent: SafariPasskeyLoginView
        
        init(_ parent: SafariPasskeyLoginView) {
            self.parent = parent
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            parent.onDismiss()
        }
    }
}

struct ContentView: View {
    @State private var targetURL = "https://antigravity.google.com"
    @State private var isShowingSettings = false
    @State private var isShowingPasskeyLogin = false
    @State private var keepScreenAwake = true
    @StateObject private var voiceManager = VoiceSpeechManager()
    @State private var webViewCoordinator: OptimizedWebView.Coordinator?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OptimizedWebView(urlString: targetURL, onCoordinatorReady: { coord in
                self.webViewCoordinator = coord
            })
            .edgesIgnoringSafeArea(.all)
            
            // Floating Control Bar
            VStack(spacing: 12) {
                Spacer()
                HStack(spacing: 12) {
                    Spacer()
                    
                    // Passkey / Face ID Login Button (for seamless Google Auth)
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        isShowingPasskeyLogin = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "faceid")
                                .font(.system(size: 16, weight: .bold))
                            Text("Passkey")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Color.indigo)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        )
                    }
                    
                    // Voice Mic Button
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()
                        
                        if voiceManager.isRecording {
                            voiceManager.stopSpeechToText()
                        } else {
                            voiceManager.showVoiceSheet = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: voiceManager.isRecording ? "waveform.circle.fill" : "mic.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            if voiceManager.isRecording {
                                Text("Đang nghe...")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(14)
                        .background(
                            Capsule()
                                .fill(voiceManager.isRecording ? Color.red : Color.blue)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        )
                    }
                    
                    // Settings Button
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        isShowingSettings.toggle()
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                            )
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
            voiceManager.requestPermissions()
        }
        .sheet(isPresented: $isShowingPasskeyLogin) {
            if let loginUrl = URL(string: targetURL) {
                SafariPasskeyLoginView(url: loginUrl) {
                    isShowingPasskeyLogin = false
                    // Reload webview to immediately pick up cookies/session
                    webViewCoordinator?.reload()
                }
            }
        }
        .sheet(isPresented: $voiceManager.showVoiceSheet) {
            VoiceInputModal(voiceManager: voiceManager) { spokenText in
                webViewCoordinator?.injectPromptToChat(spokenText)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(targetURL: $targetURL, keepScreenAwake: $keepScreenAwake)
        }
    }
}

// MARK: - Voice Input Modal
struct VoiceInputModal: View {
    @ObservedObject var voiceManager: VoiceSpeechManager
    @Environment(\.presentationMode) var presentationMode
    var onSendText: (String) -> Void
    @State private var localText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Animated Pulsing Mic
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: voiceManager.isRecording ? 140 : 100, height: voiceManager.isRecording ? 140 : 100)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: voiceManager.isRecording)
                    
                    Circle()
                        .fill(voiceManager.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 8)
                    
                    Image(systemName: voiceManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .onTapGesture {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    if voiceManager.isRecording {
                        voiceManager.stopSpeechToText()
                    } else {
                        voiceManager.recognizedText = ""
                        voiceManager.startSpeechToText { text in
                            localText = text
                        }
                    }
                }
                
                Text(voiceManager.isRecording ? "Đang lắng nghe... Chạm để dừng" : "Chạm vào Micro để bắt đầu nói")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Live Spoken Text Preview
                ScrollView {
                    Text(localText.isEmpty ? (voiceManager.isRecording ? "Hãy nói câu lệnh của bạn..." : "Văn bản nhận diện giọng nói sẽ hiển thị tại đây.") : localText)
                        .font(.system(size: 18, weight: .medium))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .frame(maxHeight: 180)
                .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {
                        voiceManager.stopSpeechToText()
                        localText = ""
                    }) {
                        Text("Xóa")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        voiceManager.stopSpeechToText()
                        if !localText.isEmpty {
                            onSendText(localText)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Gửi vào Antigravity")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(localText.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(localText.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Lệnh giọng nói")
            .navigationBarItems(trailing: Button("Đóng") {
                voiceManager.stopSpeechToText()
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                localText = ""
                voiceManager.startSpeechToText { text in
                    localText = text
                }
            }
        }
    }
}

// MARK: - WebView Container
struct OptimizedWebView: UIViewRepresentable {
    let urlString: String
    var onCoordinatorReady: ((Coordinator) -> Void)?
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: OptimizedWebView
        var progressView: UIProgressView!
        var refreshControl: UIRefreshControl!
        weak var webView: WKWebView?
        private var progressObservation: NSKeyValueObservation?
        
        init(_ parent: OptimizedWebView) {
            self.parent = parent
        }
        
        func setupProgressAndRefresh(on webView: WKWebView) {
            self.webView = webView
            
            refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
            webView.scrollView.refreshControl = refreshControl
            
            progressView = UIProgressView(progressViewStyle: .default)
            progressView.translatesAutoresizingMaskIntoConstraints = false
            progressView.tintColor = .systemBlue
            progressView.trackTintColor = .clear
            webView.addSubview(progressView)
            
            NSLayoutConstraint.activate([
                progressView.topAnchor.constraint(equalTo: webView.safeAreaLayoutGuide.topAnchor),
                progressView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
                progressView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
                progressView.heightAnchor.constraint(equalToConstant: 2.5)
            ])
            
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                guard let self = self else { return }
                self.progressView.progress = Float(webView.estimatedProgress)
                if webView.estimatedProgress >= 1.0 {
                    UIView.animate(withDuration: 0.3, delay: 0.2, options: .curveEaseOut, animations: {
                        self.progressView.alpha = 0
                    }) { _ in
                        self.progressView.progress = 0
                    }
                } else {
                    self.progressView.alpha = 1
                }
            }
        }
        
        @objc func handleRefresh() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            webView?.reload()
            refreshControl.endRefreshing()
        }
        
        func reload() {
            webView?.reload()
        }
        
        func injectPromptToChat(_ text: String) {
            let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
                                  .replacingOccurrences(of: "\"", with: "\\\"")
                                  .replacingOccurrences(of: "\n", with: "\\n")
            let js = """
            (function() {
                var input = document.querySelector('textarea, [contenteditable="true"], input[type="text"]');
                if (input) {
                    if (input.tagName === 'TEXTAREA' || input.tagName === 'INPUT') {
                        input.value = (input.value ? input.value + ' ' : '') + "\(escapedText)";
                        input.dispatchEvent(new Event('input', { bubbles: true }));
                        input.focus();
                    } else if (input.isContentEditable) {
                        input.innerText = (input.innerText ? input.innerText + ' ' : '') + "\(escapedText)";
                        input.dispatchEvent(new Event('input', { bubbles: true }));
                        input.focus();
                    }
                }
            })();
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        
        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let cssInjection = """
            var style = document.createElement('style');
            style.innerHTML = `
                * {
                    -webkit-tap-highlight-color: transparent !important;
                    touch-action: manipulation !important;
                }
                body, html {
                    -webkit-overflow-scrolling: touch !important;
                }
            `;
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(cssInjection, completionHandler: nil)
        }
        
        deinit {
            progressObservation?.invalidate()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coord = Coordinator(self)
        DispatchQueue.main.async {
            self.onCoordinatorReady?(coord)
        }
        return coord
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.allowsBackForwardNavigationGestures = true
        
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
        
        context.coordinator.setupProgressAndRefresh(on: webView)
        
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url?.absoluteString != urlString, let url = URL(string: urlString) {
            uiView.load(URLRequest(url: url))
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var targetURL: String
    @Binding var keepScreenAwake: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var tempURL: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Connection")) {
                    TextField("Server URL", text: $tempURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }
                
                Section(header: Text("Quick Presets")) {
                    Button(action: { tempURL = "https://antigravity.google.com" }) {
                        HStack {
                            Text("Official (antigravity.google.com)")
                            Spacer()
                            if tempURL == "https://antigravity.google.com" {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                    Button(action: { tempURL = "http://192.168.1.100:8080" }) {
                        HStack {
                            Text("Local Network (LAN IP)")
                            Spacer()
                            if tempURL.contains("192.168.") {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section(header: Text("Display & Experience")) {
                    Toggle("Keep Screen Awake (No Sleep)", isOn: $keepScreenAwake)
                }
            }
            .navigationTitle("App Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    targetURL = tempURL
                    UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                tempURL = targetURL
            }
        }
    }
}