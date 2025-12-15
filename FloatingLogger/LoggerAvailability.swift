//
//  LoggerAvailability.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import Foundation

enum LoggerAvailability {

    static var isEnabled: Bool {
#if DEBUG
        return true
#else
        return Bundle.main.appStoreReceiptURL?
            .lastPathComponent == "sandboxReceipt"
#endif
    }

    static var diskEnabled: Bool {
#if DEBUG
        return true
#else
        return Bundle.main.appStoreReceiptURL?
            .lastPathComponent == "sandboxReceipt"
#endif
    }
}
