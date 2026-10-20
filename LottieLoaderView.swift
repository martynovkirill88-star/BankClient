import SwiftUI
import WebKit

struct LottieWhiteLoaderView: View {
    @State private var useNativeFallback = false
    
    var body: some View {
        ZStack {
            LottieWebView(onFail: {
                useNativeFallback = true
            })
            .opacity(useNativeFallback ? 0 : 1)
            
            if useNativeFallback {
                NativeWhiteLoader()
            }
        }
        .frame(width: 140, height: 140)
    }
}

private struct LottieWebView: UIViewRepresentable {
    var onFail: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        
        var loaded = false
        if let url = Bundle.main.url(forResource: "loader", withExtension: "html"),
           let html = try? String(contentsOf: url, encoding: .utf8) {
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            loaded = true
        } else if let path = Bundle.main.path(forResource: "loader", ofType: "html"),
                  let html = try? String(contentsOfFile: path, encoding: .utf8) {
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            loaded = true
        }
        
        if !loaded {
            DispatchQueue.main.async {
                onFail()
            }
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct NativeWhiteLoader: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .scaleEffect(isAnimating ? 1.0 : 0.35)
                    .opacity(isAnimating ? 1.0 : 0.35)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
