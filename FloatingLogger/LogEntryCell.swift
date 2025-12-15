//
//  LogEntry.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import UIKit

final class LogEntryCell: UITableViewCell {
    static let reuseIdentifier = "LogEntryCell"
    
    private let logLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let viewMoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("View More", for: .normal)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var onViewMore: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(logLabel)
        contentView.addSubview(viewMoreButton)
        
        NSLayoutConstraint.activate([
            logLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            logLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            logLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            viewMoreButton.topAnchor.constraint(equalTo: logLabel.bottomAnchor, constant: 4),
            viewMoreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            viewMoreButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
        viewMoreButton.addTarget(self, action: #selector(viewMoreTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with text: String, level: String, showViewMore: Bool, onViewMore: (() -> Void)?) {
        let displayText = "[\(level.uppercased())] " + (showViewMore ? String(text.prefix(1000)) + "..." : text)
        logLabel.text = displayText
        viewMoreButton.isHidden = !showViewMore
        self.onViewMore = onViewMore
    }
    
    @objc private func viewMoreTapped() {
        onViewMore?()
    }
}
