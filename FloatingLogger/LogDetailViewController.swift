//
//  LogEntry.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import UIKit

final class LogDetailViewController: UIViewController {
    private let logText: String
    private var filteredText: String?
    private var currentSearchText: String? // Track current search

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private lazy var searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search in log"
        sb.delegate = self
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()

    private lazy var closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Close", for: .normal)
        btn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    init(logText: String) {
        self.logText = logText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        updateTextView()
    }

    private func setupUI() {
        view.addSubview(searchBar)
        view.addSubview(closeButton)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            textView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }

    private func updateTextView() {
        if let search = currentSearchText, !search.isEmpty {
            let attributed = NSMutableAttributedString(string: logText)
            let logTextLower = logText.lowercased()
            let searchLower = search.lowercased()
            var searchRange = logTextLower.startIndex..<logTextLower.endIndex
            while let foundRange = logTextLower.range(of: searchLower, options: [], range: searchRange) {
                let nsRange = NSRange(foundRange, in: logText)
                attributed.addAttribute(.backgroundColor, value: UIColor.yellow, range: nsRange)
                searchRange = foundRange.upperBound..<logTextLower.endIndex
            }
            textView.attributedText = attributed
        } else {
            textView.attributedText = NSAttributedString(string: logText)
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
}

extension LogDetailViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentSearchText = searchText
        updateTextView()
    }
}
