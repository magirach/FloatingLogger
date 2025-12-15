//
//  LogEntry.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import Foundation

public enum LogLevel: String {
    case debug, info, warning, error
}

public struct LogEntry {
    let timestamp: String
    let message: String
    let file: String
    let function: String
    let line: Int
    let level: LogLevel
    
}
