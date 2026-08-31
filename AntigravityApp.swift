import SwiftUI
import WebKit

@main
struct AntigravityRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct ContentView: View {
    @State private var targetURL = "https://antigravity.google"
    @State private var isShowingSettings = false
    @State private var keepScreenAwake = true
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OptimizedWebView(urlString: targetURL)
                .edgesIgnoringSafeArea(.all)
            
            // Floating Quick Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
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
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(targetURL: $targetURL, keepScreenAwake: $keepScreenAwake)
        }
    }
}

struct OptimizedWebView: UIViewRepresentable {
    let urlString: String
    
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
            
            // Native Pull-to-refresh
            refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
            webView.scrollView.refreshControl = refreshControl
            
            // Native slim progress bar at top
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
        Coordinator(self)
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
                    Button(action: { tempURL = "https://antigravity.google" }) {
                        HStack {
                            Text("Official (antigravity.google)")
                            Spacer()
                            if tempURL == "https://antigravity.google" {
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