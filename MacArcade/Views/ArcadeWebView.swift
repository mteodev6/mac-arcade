import AppKit
import SwiftUI
import WebKit

struct ArcadeWebView: NSViewRepresentable {
    let url: URL
    let reloadToken: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webpagePreferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.underPageBackgroundColor = NSColor(red: 0.035, green: 0.04, blue: 0.055, alpha: 1)

        context.coordinator.parent = self
        context.coordinator.currentURL = url
        context.coordinator.lastReloadToken = reloadToken
        isLoading = true
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        DispatchQueue.main.async {
            if let window = webView.window {
                window.makeFirstResponder(webView)
            }
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.currentURL != url {
            context.coordinator.currentURL = url
            context.coordinator.lastReloadToken = reloadToken
            isLoading = true
            errorMessage = nil
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        } else if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            isLoading = true
            errorMessage = nil
            webView.reload()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ArcadeWebView
        var currentURL: URL?
        var lastReloadToken: Int

        init(parent: ArcadeWebView) {
            self.parent = parent
            self.currentURL = nil
            self.lastReloadToken = parent.reloadToken
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.errorMessage = nil
            if let window = webView.window {
                window.makeFirstResponder(webView)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.targetFrame?.isMainFrame != false,
                  let destination = navigationAction.request.url,
                  destination.scheme == "http" || destination.scheme == "https" else {
                decisionHandler(.allow)
                return
            }

            guard !isLocalPlayerURL(destination) else {
                decisionHandler(.allow)
                return
            }

            // Keep the arcade shell in place for redirects and only open an
            // external destination in the browser after an explicit user click.
            if navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(destination)
            }
            decisionHandler(.cancel)
        }

        private func isLocalPlayerURL(_ destination: URL) -> Bool {
            destination.scheme == "http" &&
            destination.host == "127.0.0.1" &&
            destination.port == parent.url.port
        }

        private func show(_ error: Error) {
            parent.isLoading = false
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            parent.errorMessage = "The game page couldn't be loaded. \(error.localizedDescription)"
        }
    }
}
