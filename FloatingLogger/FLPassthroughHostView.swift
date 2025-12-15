//
//  FLPassthroughHostView.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import Foundation

final class FLPassthroughHostView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for sub in subviews {
            if sub.isHidden || sub.alpha <= 0.01 { continue }
            let p = convert(point, to: sub)
            if sub.point(inside: p, with: event) {
                return true
            }
        }
        return false
    }
}
