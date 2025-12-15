//
//  DiskLogWriter.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import Foundation

final class DiskLogWriter {

    private let queue = DispatchQueue(label: "floating.logger.disk", qos: .utility)
    private let url: URL

    init() {
        url = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("floating_logger.log")
    }

    func append(_ entry: LogEntry) {
        guard LoggerAvailability.diskEnabled else { return }

        queue.async {
            let line =
                "[\(entry.timestamp)] [\(entry.level.rawValue.uppercased())] \(entry.message)\n"

            guard let data = line.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: self.url.path) {
                let handle = try? FileHandle(forWritingTo: self.url)
                handle?.seekToEndOfFile()
                handle?.write(data)
                handle?.closeFile()
            } else {
                try? data.write(to: self.url)
            }
        }
    }

    func clear() {
        queue.async {
            if FileManager.default.fileExists(atPath: self.url.path) {
                try? FileManager.default.removeItem(at: self.url)
            }
        }
    }

    func exportURL() -> URL {
        url
    }
}
