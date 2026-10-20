import SwiftUI
import WebKit

// MARK: - In-App Mini-App Browser (WKWebView Wrapper with Zoom & Pinch Prevention)
struct InAppWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let userAgent: String
    @Binding var estimatedProgress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    var reloadTrigger: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Inject script to enforce non-scalable viewport and disable double-tap / gesture zoom
        let preventZoomScriptSource = """
        (function() {
            function enforceNativeLayout() {
                var meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    if (document.head) {
                        document.head.appendChild(meta);
                    }
                }
                if (meta) {
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, shrink-to-fit=no, viewport-fit=cover';
                }
                
                var style = document.getElementById('ropay-native-app-style');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'ropay-native-app-style';
                    style.innerHTML = `
                        html, body {
                            touch-action: pan-x pan-y !important;
                            -webkit-text-size-adjust: 100% !important;
                            -webkit-user-select: none !important;
                            user-select: none !important;
                            -webkit-touch-callout: none !important;
                        }
                        input, textarea, select, [contenteditable="true"] {
                            -webkit-user-select: auto !important;
                            user-select: auto !important;
                            font-size: 16px !important;
                        }
                    `;
                    if (document.head) {
                        document.head.appendChild(style);
                    }
                }
            }
            
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', enforceNativeLayout);
            } else {
                enforceNativeLayout();
            }
            
            // Disable double-tap to zoom
            var lastTouchTime = 0;
            document.addEventListener('touchend', function(event) {
                var currentTime = (new Date()).getTime();
                var tapLength = currentTime - lastTouchTime;
                if (tapLength < 350 && tapLength > 0) {
                    event.preventDefault();
                }
                lastTouchTime = currentTime;
            }, { passive: false });
            
            // Disable multi-touch gesture zoom
            document.addEventListener('gesturestart', function(e) { e.preventDefault(); }, { passive: false });
            document.addEventListener('gesturechange', function(e) { e.preventDefault(); }, { passive: false });
            document.addEventListener('gestureend', function(e) { e.preventDefault(); }, { passive: false });
        })();
        """
        
        let userScript = WKUserScript(
            source: preventZoomScriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = userAgent
        webView.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0)
        webView.isOpaque = false
        
        // Native ScrollView Zoom Lock
        webView.scrollView.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0)
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bouncesZoom = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.delegate = context.coordinator
        
        // Disable gesture recognizers
        Self.disableZoomGestures(in: webView)
        
        context.coordinator.setupProgressObserver(webView: webView)
        
        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "X-RoPay-App")
        request.setValue("1.0.23", forHTTPHeaderField: "X-RoPay-Version")
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        Self.disableZoomGestures(in: webView)
        if reloadTrigger != context.coordinator.lastReloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            webView.reload()
        }
    }
    
    static func disableZoomGestures(in view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.pinchGestureRecognizer?.isEnabled = false
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = 1.0
            scrollView.bouncesZoom = false
        }
        for gesture in view.gestureRecognizers ?? [] {
            if gesture is UIPinchGestureRecognizer {
                gesture.isEnabled = false
            } else if let tap = gesture as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                tap.isEnabled = false
            }
        }
        for subview in view.subviews {
            disableZoomGestures(in: subview)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: InAppWebViewRepresentable
        var lastReloadTrigger: Bool = false
        private var observation: NSKeyValueObservation?
        
        init(_ parent: InAppWebViewRepresentable) {
            self.parent = parent
        }
        
        func setupProgressObserver(webView: WKWebView) {
            observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.estimatedProgress = webView.estimatedProgress
                    self?.parent.canGoBack = webView.canGoBack
                    self?.parent.canGoForward = webView.canGoForward
                }
            }
        }
        
        // Completely forbid zoom at the UIScrollView level
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return nil
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            InAppWebViewRepresentable.disableZoomGestures(in: webView)
            
            // Re-enforce viewport
            let script = """
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                if (document.head) { document.head.appendChild(meta); }
            }
            if (meta) {
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, shrink-to-fit=no, viewport-fit=cover';
            }
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
            
            DispatchQueue.main.async {
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }
    }
}

// MARK: - RoPay In-App Browser Screen
struct RoPayInAppBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    let service: BankService
    let userId: Int?
    
    @State private var estimatedProgress: Double = 0.0
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var reloadTrigger: Bool = false
    
    var destinationURL: URL {
        var urlString = service.target_url
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }
        
        // Append secure in-app parameters
        let delimiter = urlString.contains("?") ? "&" : "?"
        let uidParam = userId != nil ? "&uid=\(userId!)" : ""
        let finalUrlString = "\(urlString)\(delimiter)ropay_inapp=1\(uidParam)"
        
        return URL(string: finalUrlString) ?? URL(string: "https://app.ropay.site")!
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(BankTheme.bgCardSecondary)
                                .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(BankTheme.mint)
                                Text("Защищённый сервис RoPay")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(BankTheme.mint)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            reloadTrigger.toggle()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                                .padding(8)
                                .background(BankTheme.bgCardSecondary)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .background(BankTheme.bgDarkSecondary)
                    
                    // Loading Progress Indicator
                    if estimatedProgress < 1.0 {
                        ProgressView(value: estimatedProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: BankTheme.mint))
                            .frame(height: 2)
                    } else {
                        Divider().background(BankTheme.border)
                    }
                    
                    // WKWebView Content
                    InAppWebViewRepresentable(
                        url: destinationURL,
                        userAgent: "RoPayClientApp/1.0.23 (iPhone; iOS 26.0) RoPaySecureInAppBrowser",
                        estimatedProgress: $estimatedProgress,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        reloadTrigger: reloadTrigger
                    )
                }
            }
            .navigationBarHidden(true)
        }
    }
}
