import SwiftUI
import WebKit

// MARK: - Button style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

final class ScrollroomCoordinator: NSObject {
    weak var webView: WKWebView?
    private var redirectCount = 0, maxRedirects = 70
    private var lastURL: URL?, checkpoint: URL?
    private var popups: [WKWebView] = []
    private let cookieJar = LedgerGlossary.cookiePages
    
    func loadURL(_ url: URL, in webView: WKWebView) {
        redirectCount = 0
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
    }
    
    func loadCookies(in webView: WKWebView) async {
        guard let cookieData = UserDefaults.standard.object(forKey: cookieJar) as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = cookieData.values.flatMap { $0.values }.compactMap { HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any]) }
        cookies.forEach { cookieStore.setCookie($0) }
    }
    
    private func saveCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            var cookieData: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for cookie in cookies {
                var domainCookies = cookieData[cookie.domain] ?? [:]
                if let properties = cookie.properties { domainCookies[cookie.name] = properties }
                cookieData[cookie.domain] = domainCookies
            }
            UserDefaults.standard.set(cookieData, forKey: self.cookieJar)
        }
    }
}

struct LLButton: View {
    enum Kind { case primary, secondary, success, danger, ghost }

    let title: String
    var icon: String? = nil
    var kind: Kind = .primary
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon).font(.ll(15, .semibold)) }
                Text(title).font(.ll(16, .semibold))
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .foregroundColor(foreground)
            .background(background)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(strokeColor, lineWidth: kind == .ghost ? 1.5 : 0)
            )
            .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var foreground: Color {
        switch kind {
        case .primary: return AppColor.onAccent
        case .secondary: return AppColor.onAccent
        case .success: return AppColor.onSuccess
        case .danger: return AppColor.onSuccess
        case .ghost: return AppColor.textPrimary
        }
    }
    @ViewBuilder private var background: some View {
        switch kind {
        case .primary: AppColor.accentGradient
        case .secondary: AppColor.depth
        case .success: AppColor.good
        case .danger: AppColor.problem
        case .ghost: Color.clear
        }
    }
    private var strokeColor: Color { AppColor.borderStrong }
    private var shadowColor: Color {
        switch kind {
        case .primary: return AppColor.yolkGlow
        case .success: return AppColor.good.opacity(0.25)
        case .danger: return AppColor.problem.opacity(0.25)
        default: return Color.clear
        }
    }
}


extension ScrollroomCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        lastURL = url
        let scheme = (url.scheme ?? "").lowercased()
        let path = url.absoluteString.lowercased()
        let allowedSchemes: Set<String> = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let specialPaths = ["srcdoc", "about:blank", "about:srcdoc"]
        if allowedSchemes.contains(scheme) || specialPaths.contains(where: { path.hasPrefix($0) }) || path == "about:blank" {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url, options: [:])
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        if redirectCount > maxRedirects { webView.stopLoading(); if let recovery = lastURL { webView.load(URLRequest(url: recovery)) }; redirectCount = 0; return }
        lastURL = webView.url; saveCookies(from: webView)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }; redirectCount = 0; saveCookies(from: webView)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let recovery = lastURL { webView.load(URLRequest(url: recovery)) }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.card)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColor.border, lineWidth: 1))
            .shadow(color: AppColor.shadow, radius: 10, x: 0, y: 6)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ll(20, .bold)).foregroundColor(AppColor.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle).font(.captionM).foregroundColor(AppColor.textSecondary)
                }
            }
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle).font(.ll(14, .semibold)).foregroundColor(AppColor.accentActive)
                }
            }
        }
    }
}


extension ScrollroomCoordinator: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        let popup = WKWebView(frame: webView.bounds, configuration: configuration)
        popup.navigationDelegate = self; popup.uiDelegate = self; popup.allowsBackForwardNavigationGestures = true
        guard let parentView = webView.superview else { return nil }
        parentView.addSubview(popup); popup.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([popup.topAnchor.constraint(equalTo: webView.topAnchor), popup.bottomAnchor.constraint(equalTo: webView.bottomAnchor), popup.leadingAnchor.constraint(equalTo: webView.leadingAnchor), popup.trailingAnchor.constraint(equalTo: webView.trailingAnchor)])
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePopupPan(_:))); gesture.delegate = self
        popup.scrollView.panGestureRecognizer.require(toFail: gesture); popup.addGestureRecognizer(gesture); popups.append(popup)
        if let url = navigationAction.request.url, url.absoluteString != "about:blank" { popup.load(navigationAction.request) }
        return popup
    }
    @objc private func handlePopupPan(_ recognizer: UIPanGestureRecognizer) {
        guard let popupView = recognizer.view else { return }
        let translation = recognizer.translation(in: popupView), velocity = recognizer.velocity(in: popupView)
        switch recognizer.state {
        case .changed: if translation.x > 0 { popupView.transform = CGAffineTransform(translationX: translation.x, y: 0) }
        case .ended, .cancelled:
            let shouldClose = translation.x > popupView.bounds.width * 0.4 || velocity.x > 800
            if shouldClose { UIView.animate(withDuration: 0.25, animations: { popupView.transform = CGAffineTransform(translationX: popupView.bounds.width, y: 0) }) { [weak self] _ in self?.dismissTopPopup() }
            } else { UIView.animate(withDuration: 0.2) { popupView.transform = .identity } }
        default: break
        }
    }
    private func dismissTopPopup() { guard let last = popups.last else { return }; last.removeFromSuperview(); popups.removeLast() }
    func webViewDidClose(_ webView: WKWebView) { if let index = popups.firstIndex(of: webView) { webView.removeFromSuperview(); popups.remove(at: index) } }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
}

struct StatTile: View {
    let title: String
    let value: String
    var unit: String? = nil
    var icon: String
    var tint: Color = AppColor.accent

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(tint.opacity(0.18)).frame(width: 34, height: 34)
                        Image(systemName: icon).font(.ll(15, .bold)).foregroundColor(tint)
                    }
                    Spacer()
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value).font(.ll(26, .bold)).foregroundColor(AppColor.textPrimary)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if let unit = unit {
                        Text(unit).font(.captionM).foregroundColor(AppColor.textSecondary)
                    }
                }
                Text(title).font(.captionM).foregroundColor(AppColor.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let status: LayStatus
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.icon).font(.ll(11, .bold))
            Text(status.title).font(.ll(12, .semibold))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Tag chip

struct TagChip: View {
    let text: String
    var color: Color = AppColor.teal
    var filled: Bool = false
    var body: some View {
        Text(text)
            .font(.ll(12, .semibold))
            .foregroundColor(filled ? .white : color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(filled ? color : color.opacity(0.15))
            .clipShape(Capsule())
    }
}

extension ScrollroomCoordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { return true }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
        let velocity = pan.velocity(in: view), translation = pan.translation(in: view)
        return translation.x > 0 && abs(velocity.x) > abs(velocity.y)
    }
}

struct LabeledTextField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.captionM).foregroundColor(AppColor.textSecondary)
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon).foregroundColor(AppColor.textDisabled)
                }
                TextField(placeholder, text: $text)
                    .font(.bodyM)
                    .foregroundColor(AppColor.textPrimary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(AppColor.bgSecondary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.border, lineWidth: 1))
        }
    }
}

struct LabeledNumberField: View {
    let label: String
    var placeholder: String = "0"
    @Binding var value: String
    var icon: String? = nil
    var unit: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.captionM).foregroundColor(AppColor.textSecondary)
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon).foregroundColor(AppColor.textDisabled)
                }
                TextField(placeholder, text: $value)
                    .keyboardType(.decimalPad)
                    .font(.bodyM)
                    .foregroundColor(AppColor.textPrimary)
                if let unit = unit {
                    Text(unit).font(.captionM).foregroundColor(AppColor.textDisabled)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(AppColor.bgSecondary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.border, lineWidth: 1))
        }
    }
}

struct LabeledMultilineField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.captionM).foregroundColor(AppColor.textSecondary)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Add details…")
                        .font(.bodyM).foregroundColor(AppColor.textDisabled)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                TextEditor(text: $text)
                    .font(.bodyM)
                    .foregroundColor(AppColor.textPrimary)
                    .frame(minHeight: 90)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.clear)
            }
            .background(AppColor.bgSecondary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.border, lineWidth: 1))
        }
    }
}

// MARK: - Segmented control

struct LLSegmented<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.ll(14, .semibold))
                        .foregroundColor(isSelected ? AppColor.onAccent : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 10).fill(AppColor.accentGradient)
                                }
                            }
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(4)
        .background(AppColor.depth)
        .cornerRadius(13)
    }
}

// MARK: - Stepper field

struct StepperField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...100000
    var step: Int = 1
    var body: some View {
        HStack {
            Text(label).font(.bodyM).foregroundColor(AppColor.textPrimary)
            Spacer()
            HStack(spacing: 0) {
                stepButton(icon: "minus") {
                    value = max(range.lowerBound, value - step)
                }
                Text("\(value)")
                    .font(.ll(17, .bold))
                    .foregroundColor(AppColor.textPrimary)
                    .frame(minWidth: 46)
                stepButton(icon: "plus") {
                    value = min(range.upperBound, value + step)
                }
            }
            .background(AppColor.bgSecondary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.border, lineWidth: 1))
        }
    }
    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.ll(14, .bold))
                .foregroundColor(AppColor.accentActive)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(AppColor.accent.opacity(0.14)).frame(width: 78, height: 78)
                Image(systemName: icon).font(.ll(30, .bold)).foregroundColor(AppColor.accent)
            }
            Text(title).font(.headline).foregroundColor(AppColor.textPrimary)
            Text(message).font(.bodyM).foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle = actionTitle, let action = action {
                LLButton(title: actionTitle, icon: "plus", fullWidth: false, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

// MARK: - Screen background

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppColor.bgGradient.ignoresSafeArea()
            content
        }
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }
    /// Bottom inset so floating tab bar never covers content.
    func bottomBarInset() -> some View { padding(.bottom, 96) }
}

// MARK: - Toast

struct ToastView: View {
    let message: String
    var icon: String = "checkmark.circle.fill"
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(AppColor.good)
            Text(message).font(.ll(14, .semibold)).foregroundColor(AppColor.textPrimary)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(AppColor.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColor.border, lineWidth: 1))
        .shadow(color: AppColor.shadow, radius: 12, x: 0, y: 8)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    var icon: String = "checkmark.circle.fill"

    func body(content: Content) -> some View {
        ZStack {
            content
            if isShowing {
                VStack {
                    Spacer()
                    ToastView(message: message, icon: icon)
                        .padding(.bottom, 110)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isShowing = false }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, icon: icon))
    }
}

// MARK: - Egg logo shape

struct EggShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Asymmetric egg: pointier top, rounder bottom.
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.62),
                   control1: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h * 0.02),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.30))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.86),
                   control2: CGPoint(x: rect.minX + w * 0.70, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.62),
                   control1: CGPoint(x: rect.minX + w * 0.30, y: rect.maxY),
                   control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.86))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.30),
                   control2: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.02))
        p.closeSubpath()
        return p
    }
}
