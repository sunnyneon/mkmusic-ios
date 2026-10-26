import UIKit
import WebKit

/// Shows the fan app from mkmusic.app/app. "?source=ios" tells the website it is inside the
/// Apple app, so it hides Buy / Join Premium / shop links (Apple rules) — same as the Play Store app.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    static let startURL = URL(string: "https://mkmusic.app/app?source=ios")!
    private static let appHosts: Set<String> = ["mkmusic.app", "www.mkmusic.app"]
    /// Pages that open inside the app. Any other link opens in Safari.
    private static let inAppPaths = ["/app", "/auth", "/policy", "/terms", "/refund-policy", "/contact"]

    private static let topColor = UIColor(red: 0x0f / 255, green: 0x0d / 255, blue: 0x0b / 255, alpha: 1)
    private static let navColor = UIColor(red: 0x14 / 255, green: 0x11 / 255, blue: 0x0e / 255, alpha: 1)

    private var webView: WKWebView!
    private let offlineView = OfflineView()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.topColor

        // Fills the strip under the home bar so it matches the app's bottom menu.
        let bottomFill = UIView()
        bottomFill.backgroundColor = Self.navColor
        bottomFill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomFill)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default() // keeps fans signed in
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        config.applicationNameForUserAgent = "Mobile/15E148 Safari/604.1 MKmusic-iOS/\(version)"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = Self.topColor
        webView.scrollView.backgroundColor = Self.topColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        view.addSubview(webView)

        offlineView.translatesAutoresizingMaskIntoConstraints = false
        offlineView.isHidden = true
        offlineView.onRetry = { [weak self] in self?.retry() }
        view.addSubview(offlineView)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: safe.topAnchor),
            webView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            bottomFill.topAnchor.constraint(equalTo: safe.bottomAnchor),
            bottomFill.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFill.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFill.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            offlineView.topAnchor.constraint(equalTo: view.topAnchor),
            offlineView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            offlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        webView.load(URLRequest(url: Self.startURL))
    }

    private func retry() {
        offlineView.isHidden = true
        if webView.url == nil { webView.load(URLRequest(url: Self.startURL)) } else { webView.reload() }
    }

    private static func opensInApp(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), appHosts.contains(host) else { return false }
        let path = url.path.isEmpty ? "/" : url.path
        return inAppPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private func openOutside(_ url: URL) {
        UIApplication.shared.open(url)
    }

    // MARK: Links

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow); return
        }
        if ["about", "blob", "data", "javascript"].contains(scheme) { decisionHandler(.allow); return }
        if scheme == "http" || scheme == "https" {
            // Embedded frames (e.g. a video player) load normally.
            if let frame = navigationAction.targetFrame, !frame.isMainFrame { decisionHandler(.allow); return }
            if Self.opensInApp(url) { decisionHandler(.allow); return }
        }
        openOutside(url) // other websites, email, phone links
        decisionHandler(.cancel)
    }

    // Links that open a new window (target="_blank" / window.open)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if Self.opensInApp(url) { webView.load(URLRequest(url: url)) } else { openOutside(url) }
        }
        return nil
    }

    // MARK: Loading / offline

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        offlineView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showOfflineIfNeeded(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showOfflineIfNeeded(error)
    }

    private func showOfflineIfNeeded(_ error: Error) {
        let e = error as NSError
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        if e.domain == "WebKitErrorDomain" && (e.code == 102 || e.code == 204) { return } // link handed to Safari / media
        offlineView.isHidden = false
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // MARK: Pop-up messages from the website (alert / confirm)

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}

/// Shown when there's no internet.
final class OfflineView: UIView {
    var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0x0f / 255, green: 0x0d / 255, blue: 0x0b / 255, alpha: 1)

        let title = UILabel()
        title.text = "Can't reach MKmusic"
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.textColor = .white
        title.textAlignment = .center

        let body = UILabel()
        body.text = "Check your internet connection, then try again."
        body.font = .systemFont(ofSize: 16)
        body.textColor = UIColor(white: 1, alpha: 0.7)
        body.textAlignment = .center
        body.numberOfLines = 0

        var cfg = UIButton.Configuration.filled()
        cfg.title = "Try again"
        cfg.cornerStyle = .capsule
        cfg.baseBackgroundColor = UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)
        cfg.baseForegroundColor = .black
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28)
        let button = UIButton(configuration: cfg)
        button.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, body, button])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
