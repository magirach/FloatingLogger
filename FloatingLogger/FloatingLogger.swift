//
//  LogEntry.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import UIKit

public final class FloatingLogger: NSObject, UIGestureRecognizerDelegate, ObservableObject {

    // MARK: Singleton

    public static let shared = FloatingLogger()

    // MARK: Properties

    private weak var keyWindow: UIWindow?

    private var hostView: FLPassthroughHostView?
    private var button: UIButton?

    private var secretTap: UITapGestureRecognizer?
    private var secretTapTouches: UInt = 2
    private var secretTapTaps: UInt = 3
    private var pendingUIUpdate = false

    private var isStarted = false
    private var showFloatingButton = true
    private let diskWriter = DiskLogWriter()
    private let syncQ = DispatchQueue(label: "floating.logger.sync")
    private let buffer = LogRingBuffer(capacity: 2_000) // ~2k lines
        private var pendingUpdate = false
    @Published private(set) var visibleEntries: [LogEntry] = []


    private override init() {
        super.init()
    }

    deinit {
        unregisterLifecycleNotifications()
    }

    // MARK: Public API

    public func start() {
        guard LoggerAvailability.isEnabled else { return }
        if isStarted {
            ensureOnTop()
            return
        }
        isStarted = true
        showFloatingButton = true

        registerLifecycleNotifications()
        attachToKeyWindowAndBringToFront()
        attachGestureToKeyWindow()
    }


    public func startWithSecretGesture() {
        guard LoggerAvailability.isEnabled else { return }
        if isStarted {
            attachGestureToKeyWindow()
            return
        }
        isStarted = true
        showFloatingButton = false

        registerLifecycleNotifications()
        attachToKeyWindowAndBringToFront()
        attachGestureToKeyWindow()
    }


    public func enableSecretTap(touches: UInt, taps: UInt) {
        secretTapTouches = touches
        secretTapTaps = taps
        if isStarted {
            attachGestureToKeyWindow()
        }
    }

    public func stop() {
        isStarted = false
        unregisterLifecycleNotifications()

        if let v = secretTap?.view {
            v.removeGestureRecognizer(secretTap!)
        }
        secretTap = nil

        hostView?.removeFromSuperview()
        hostView = nil
        button = nil
        keyWindow = nil
    }

    public func log(_ message: String) {
        log(message, file: #file, function: #function, line: #line)
    }

    public func log(
            _ message: @autoclosure () -> String,
            isSecure:Bool = false,
            level: LogLevel = .debug,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard LoggerAvailability.isEnabled else { return }

            let entry = LogEntry(
                timestamp: Self.timestampString(),
                message: isSecure ? redact(message()) : message(),
                file: (file as NSString).lastPathComponent,
                function: function,
                line: line,
                level: level
            )

            syncQ.async { [weak self] in
                guard let self = self else { return }
                self.buffer.append(entry)
                self.diskWriter.append(entry)
                self.scheduleUIUpdate()
            }
        }
    private func scheduleUIUpdate() {
           guard !pendingUIUpdate else { return }
           pendingUIUpdate = true

           DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
               guard let self = self else { return }
               self.pendingUIUpdate = false
               self.visibleEntries = self.buffer.all()
           }
       }
    public func clear() {
            syncQ.async { [weak self] in
                guard let self = self else { return }
                self.buffer.clear()
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.visibleEntries = []
                    self.diskWriter.clear()
                }
            }
        }
    public func allLogsText() -> String {
        var copy: [String] = []
        syncQ.sync {
            let copy = self.buffer.all()
            let text = copy.map {
                "[\($0.timestamp)] [\($0.level.rawValue.uppercased())] \($0.message)"
            }
        }
        return copy.joined(separator: "\n")
    }
    public func applyFilter(
            search: String?,
            level: LogLevel?
        ) {
            syncQ.async { [weak self] in
                guard let self = self else { return }
                let all = self.buffer.all()
                let filtered = all.filter {
                    (level == nil || $0.level == level) &&
                    (search == nil ||
                     $0.message.localizedCaseInsensitiveContains(search!) ||
                     $0.file.localizedCaseInsensitiveContains(search!))
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.visibleEntries = filtered
                }
            }
        }

    public func logFilePath() -> URL? {
        return diskWriter.exportURL()
    }

    // MARK: Helpers

    private func ensureOnTop() {
        let key = keyWindow ?? findKeyWindow()
        guard let key, let hostView else { return }
        hostView.layer.zPosition = 9999
        button?.layer.zPosition = 10000
        key.bringSubviewToFront(hostView)
        DispatchQueue.main.async {
            key.bringSubviewToFront(hostView)
        }
    }

    private static func timestampString() -> String {
        struct Holder {
            static let df: DateFormatter = {
                let d = DateFormatter()
                d.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                return d
            }()
        }
        return Holder.df.string(from: Date())
    }

    private func registerLifecycleNotifications() {
        let nc = NotificationCenter.default

        nc.addObserver(
            self,
            selector: #selector(attachToKeyWindowAndBringToFront),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(attachToKeyWindowAndBringToFront),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )

        if #available(iOS 13.0, *) {
            nc.addObserver(
                self,
                selector: #selector(attachToKeyWindowAndBringToFront),
                name: UIScene.didActivateNotification,
                object: nil
            )
        }

        // Re-attach gesture too
        nc.addObserver(
            self,
            selector: #selector(attachGestureToKeyWindow),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(attachGestureToKeyWindow),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )

        if #available(iOS 13.0, *) {
            nc.addObserver(
                self,
                selector: #selector(attachGestureToKeyWindow),
                name: UIScene.didActivateNotification,
                object: nil
            )
        }
    }


    @objc private func attachToKeyWindowAndBringToFront() {
        guard let key = findKeyWindow() else { return }
        keyWindow = key

        if !showFloatingButton {
            // Gesture-only mode
            if hostView?.superview != nil {
                hostView?.removeFromSuperview()
            }
            hostView = nil
            button = nil
            return
        }

        if hostView == nil {
            let host = FLPassthroughHostView(frame: key.bounds)
            host.backgroundColor = .clear
            host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostView = host

            let size: CGFloat = 56.0
            let btn = UIButton(type: .system)
            btn.frame = CGRect(
                x: host.bounds.width - size - 16,
                y: host.bounds.height * 0.6,
                width: size,
                height: size
            )
            btn.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
            btn.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            btn.setTitle("🧾", for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 24, weight: .medium)
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = size / 2
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOpacity = 0.25
            btn.layer.shadowRadius = 6
            btn.layer.shadowOffset = CGSize(width: 0, height: 3)
            btn.addTarget(self, action: #selector(showLogOverlay), for: .touchUpInside)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            btn.addGestureRecognizer(pan)

            host.addSubview(btn)
            button = btn

            host.layer.zPosition = 9999
            btn.layer.zPosition = 10000
        }

        if hostView?.superview !== key {
            hostView?.removeFromSuperview()
            key.addSubview(hostView!)
        }

        key.bringSubviewToFront(hostView!)
        DispatchQueue.main.async {
            key.bringSubviewToFront(self.hostView!)
        }
    }

    @objc private func attachGestureToKeyWindow() {
        guard let key = findKeyWindow() else { return }

        if let tap = secretTap, tap.view !== key {
            tap.view?.removeGestureRecognizer(tap)
            secretTap = nil
        }

        if secretTap == nil {
            let tap = UITapGestureRecognizer(
                target: self,
                action: #selector(handleSecretTap(_:))
            )
            tap.numberOfTouchesRequired = Int(secretTapTouches)
            tap.numberOfTapsRequired = Int(secretTapTaps)
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.requiresExclusiveTouchType = false
            tap.delegate = self

            key.addGestureRecognizer(tap)
            secretTap = tap
        } else {
            secretTap?.numberOfTouchesRequired = Int(secretTapTouches)
            secretTap?.numberOfTapsRequired = Int(secretTapTaps)
            if secretTap?.view !== key {
                key.addGestureRecognizer(secretTap!)
            }
        }
    }


    private func findKeyWindow() -> UIWindow? {
        var keyWin: UIWindow?

        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                for w in ws.windows where w.isKeyWindow {
                    keyWin = w
                    break
                }
                if keyWin != nil { break }
            }

            if keyWin == nil {
                for scene in UIApplication.shared.connectedScenes {
                    guard let ws = scene as? UIWindowScene else { continue }
                    for w in ws.windows where !w.isHidden && w.alpha > 0 {
                        keyWin = w
                        break
                    }
                    if keyWin != nil { break }
                }
            }
        } else {
            keyWin = UIApplication.shared.keyWindow
                ?? UIApplication.shared.windows.first
        }

        return keyWin
    }

    private func unregisterLifecycleNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func showLogOverlay() {
        guard let top = Self.topMostViewController(nil) else { return }

        let vc = FLLogOverlayVC()
        vc.modalPresentationStyle = .fullScreen

        top.present(vc, animated: true) {
            self.ensureOnTop()
        }
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        guard let v = gr.view, let sup = hostView else { return }

        let t = gr.translation(in: sup)

        if gr.state == .changed {
            var newCenter = CGPoint(x: v.center.x + t.x, y: v.center.y + t.y)
            let inset: CGFloat = 8.0

            let minX = inset + v.bounds.width / 2
            let maxX = sup.bounds.width - v.bounds.width / 2 - inset
            let minY = inset + v.bounds.height / 2
            let maxY = sup.bounds.height - v.bounds.height / 2 - inset

            newCenter.x = max(min(newCenter.x, maxX), minX)
            newCenter.y = max(min(newCenter.y, maxY), minY)

            v.center = newCenter
            gr.setTranslation(.zero, in: sup)

        } else if gr.state == .ended {
            let left = v.center.x
            let right = sup.bounds.width - v.center.x

            UIView.animate(withDuration: 0.2) {
                v.center = CGPoint(
                    x: (left < right)
                        ? (v.bounds.width / 2 + 8)
                        : (sup.bounds.width - v.bounds.width / 2 - 8),
                    y: v.center.y
                )
            }
        }
    }

    @objc private func handleSecretTap(_ gr: UITapGestureRecognizer) {
        if gr.state == .recognized {
            showLogOverlay()
        }
    }


    static func topMostViewController(_ base: UIViewController?) -> UIViewController? {
        var root = base

        if root == nil {
            if #available(iOS 13.0, *) {
                for scene in UIApplication.shared.connectedScenes {
                    guard let ws = scene as? UIWindowScene else { continue }
                    for w in ws.windows where w.isKeyWindow {
                        root = w.rootViewController
                        break
                    }
                    if root != nil { break }
                }
            }
        }

        if root == nil {
            root = UIApplication.shared.keyWindow?.rootViewController
        }

        if let nav = root as? UINavigationController {
            return topMostViewController(nav.visibleViewController)
        }

        if let tab = root as? UITabBarController {
            let selected = tab.selectedViewController ?? root
            return topMostViewController(selected)
        }

        if let presented = root?.presentedViewController {
            return topMostViewController(presented)
        }

        return root
    }


}

import Foundation

extension FloatingLogger {

    private static let patterns: [(String, String)] = [
        // UUID (must be first to avoid false code/phone matches)
        ("\\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\b", "<REDACTED_UUID>"),

        // Email
        ("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", "<REDACTED_EMAIL>"),

        // PAN (India)
        ("\\b[A-Z]{5}[0-9]{4}[A-Z]{1}\\b", "<REDACTED_PAN>"),

        // Aadhaar (India)
        ("\\b\\d{4}\\s?\\d{4}\\s?\\d{4}\\b", "<REDACTED_AADHAAR>"),

        // SSN (US)
        ("\\b\\d{3}-\\d{2}-\\d{4}\\b", "<REDACTED_SSN>"),

        // IP addresses (IPv4)
        ("\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b", "<REDACTED_IP>"),
        // IP addresses (IPv6)
        ("\\b([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\\b", "<REDACTED_IP>"),

        // URLs
        ("https?://[a-zA-Z0-9./?=_-]+", "<REDACTED_URL>"),

        // Date of Birth (DOB) - common formats
        ("\\b(0[1-9]|[12][0-9]|3[01])[-/](0[1-9]|1[012])[-/](19|20)\\d\\d\\b", "<REDACTED_DOB>"),
        ("\\b(19|20)\\d\\d[-/](0[1-9]|1[012])[-/](0[1-9]|[12][0-9]|3[01])\\b", "<REDACTED_DOB>"),

        // Phone numbers (India, stricter: +91 or 0 or starts with 6-9)
        ("\\b(\\+91[- ]?|0)?[6-9]\\d{9}\\b", "<REDACTED_PHONE>"),

        // Amex card numbers (4-6-5 format, with space or dash)
        ("\\b\\d{4}[ -]\\d{6}[ -]\\d{5}\\b", "<REDACTED_CARD>"),
        // Credit card numbers (stricter, require at least one space or dash)
        ("\\b\\d{4}([ -]\\d{4}){2,4}\\b", "<REDACTED_CARD>"),

        // CVV (3 or 4 digits, context-aware)
        ("(?i)cvv[ :]*\\d{3,4}", "CVV:<REDACTED_CVV>"),

        // IFSC (India)
        ("\\b[A-Z]{4}0[A-Z0-9]{6}\\b", "<REDACTED_IFSC>"),

        // JWT / tokens
        ("eyJ[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+", "<REDACTED_TOKEN>"),

        // Bearer tokens
        ("(?i)Bearer [a-zA-Z0-9._-]+", "Bearer <REDACTED_TOKEN>"),

        // Passwords (common key names)
        ("(?i)(password|pass|pwd)[\"':= ]+[^\"'\\s]+", "$1:<REDACTED_PASSWORD>"),

        // Access/refresh tokens (common key names)
        ("(?i)(access|refresh)_token[\"':= ]+[^\"'\\s]+", "$1_token:<REDACTED_TOKEN>"),

        // OTP/PIN as key-value (e.g., "otp":123456, 'pin':'1234', etc.)
        ("(?i)(otp|pin|one_time_password|verification_code)[\"':= ]+\\d{4,8}", "$1:<REDACTED_CODE>")
    ]

    func redact(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in Self.patterns {
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        return result
    }
}
