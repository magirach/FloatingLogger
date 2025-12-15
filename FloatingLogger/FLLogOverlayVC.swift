//
//  LogEntry.swift
//  FloatingLogger
//
//  Created by Moinuddin Girach on 13/12/25.
//  Copyright © 2025 Moinuddin Girach. All rights reserved.
//

import UIKit
import Combine

final class FLLogOverlayVC: UIViewController {

    // MARK: - Dependencies

    private let logger: FloatingLogger
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search logs"
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()

    private lazy var btnClear: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear", for: .normal)
        button.addTarget(self, action: #selector(clearLogs), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var btnClose: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.addTarget(self, action: #selector(closeOverlay), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var btnShare: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Share", for: .normal)
        button
            .addTarget(self, action: #selector(shareLog), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Init

    init(logger: FloatingLogger = .shared) {
        self.logger = logger
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.logger = .shared
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindLogger()
        tableView.register(LogEntryCell.self, forCellReuseIdentifier: LogEntryCell.reuseIdentifier)
        tableView.delegate = self
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let buttonStack = UIStackView(
            arrangedSubviews: [btnClear, btnShare, btnClose]
        )
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually

        let topStack = UIStackView(arrangedSubviews: [searchBar, buttonStack])
        topStack.axis = .vertical
        topStack.spacing = 8
        topStack.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView(arrangedSubviews: [topStack, tableView])
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }

    // MARK: - Combine

    private func bindLogger() {
        logger.$visibleEntries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc
    private func clearLogs() {
        logger.clear()
    }

    @objc
    private func closeOverlay() {
        dismiss(animated: true, completion: nil)
    }

    @objc
    private func shareLog() {
        let logFileURL = logger.logFilePath()
        let activityVC = UIActivityViewController(activityItems: [logFileURL], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.btnShare
        present(activityVC, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource

extension FLLogOverlayVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        logger.visibleEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let entry = logger.visibleEntries[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: LogEntryCell.reuseIdentifier, for: indexPath) as! LogEntryCell

        let logText = "\(entry.timestamp) \(entry.file):\(entry.function):#\(entry.line): \(entry.message)"
        let showViewMore = logText.count > 1000
        cell.configure(
            with: logText,
            level: entry.level.rawValue,
            showViewMore: showViewMore,
            onViewMore: { [weak self] in
                guard let self = self else { return }
                let detailVC = LogDetailViewController(logText: logText)
                detailVC.modalPresentationStyle = .formSheet
                self.present(detailVC, animated: true, completion: nil)
            }
        )
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FLLogOverlayVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = logger.visibleEntries[indexPath.row]
        if entry.message.count > 1000 { return } // Only show detail for short logs on tap if needed
        let detailVC = LogDetailViewController(logText: entry.message)
        detailVC.modalPresentationStyle = .formSheet
        present(detailVC, animated: true, completion: nil)
    }
}

// MARK: - UISearchBarDelegate

extension FLLogOverlayVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        logger.applyFilter(
            search: searchText.isEmpty ? nil : searchText,
            level: nil
        )
    }
}
