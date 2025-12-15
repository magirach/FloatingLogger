//
//  LogRingBuffer.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import Foundation

final class LogRingBuffer {

    private let capacity: Int
    private var buffer: [LogEntry] = []
    private var startIndex = 0

    init(capacity: Int) {
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    func append(_ entry: LogEntry) {
        if buffer.count < capacity {
            buffer.append(entry)
        } else {
            buffer[startIndex] = entry
            startIndex = (startIndex + 1) % capacity
        }
    }

    func all() -> [LogEntry] {
        guard buffer.count == capacity else { return buffer }
        return Array(buffer[startIndex...] + buffer[..<startIndex])
    }

    func clear() {
        buffer.removeAll(keepingCapacity: true)
        startIndex = 0
    }
}
