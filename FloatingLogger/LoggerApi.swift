//
//  LoggerApi.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import Foundation

@inline(__always)
public func FLLog(
    _ items: Any...,
    level: LogLevel = .debug,
    isSecure: Bool = false,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    guard LoggerAvailability.isEnabled else { return }

    FloatingLogger.shared.log(
        items.map { String(describing: $0) }.joined(separator: " "),
        isSecure: isSecure,
        level: level,
        file: file,
        function: function,
        line: line
    )
}

@inline(__always)
public func DLog(_ items: Any...) {
#if DEBUG
    FLLog(items)
#endif
}
