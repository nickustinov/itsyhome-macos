//
//  SettingsView.swift
//  macOSBridge
//
//  Main settings view with sidebar navigation
//

import AppKit

// Flipped view for proper top-to-bottom layout in scroll views
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class SettingsView: NSView, NSTableViewDataSource, NSTableViewDelegate {

    private let sidebarTableView = NSTableView()
    private let contentContainer = NSScrollView()

    private var menuData: MenuData?

    private enum Section: Int, CaseIterable {
        case general
        case accessories
        case deeplinks
        case about

        var title: String {
            switch self {
            case .general: return "General"
            case .accessories: return "Accessories"
            case .deeplinks: return "Deeplinks"
            case .about: return "About"
            }
        }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .accessories: return "lightbulb"
            case .deeplinks: return "link"
            case .about: return "info.circle"
            }
        }
    }

    // Content views (lazily created)
    private var generalSection: GeneralSection?
    private var accessoriesSection: AccessoriesSettingsView?
    private var deeplinksSection: DeeplinksSection?
    private var aboutSection: AboutSection?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with data: MenuData) {
        self.menuData = data
        accessoriesSection?.configure(with: data)
    }

    private func setupView() {
        // Sidebar background
        let sidebarBackground = NSView()
        sidebarBackground.wantsLayer = true
        sidebarBackground.layer?.backgroundColor = NSColor(white: 0.92, alpha: 1.0).cgColor
        sidebarBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebarBackground)

        // Sidebar scroll view
        let sidebarScrollView = NSScrollView()
        sidebarScrollView.hasVerticalScroller = true
        sidebarScrollView.autohidesScrollers = true
        sidebarScrollView.drawsBackground = false
        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.width = 160
        sidebarTableView.addTableColumn(column)
        sidebarTableView.headerView = nil
        sidebarTableView.rowHeight = 36
        sidebarTableView.style = .sourceList
        sidebarTableView.dataSource = self
        sidebarTableView.delegate = self
        sidebarTableView.backgroundColor = .clear

        sidebarScrollView.documentView = sidebarTableView
        addSubview(sidebarScrollView)

        // Content scroll view
        contentContainer.hasVerticalScroller = true
        contentContainer.autohidesScrollers = true
        contentContainer.drawsBackground = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentContainer)

        // Layout
        NSLayoutConstraint.activate([
            // Sidebar background
            sidebarBackground.topAnchor.constraint(equalTo: topAnchor),
            sidebarBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarBackground.widthAnchor.constraint(equalToConstant: 200),

            // Sidebar scroll view
            sidebarScrollView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            sidebarScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarScrollView.widthAnchor.constraint(equalToConstant: 200),

            // Content
            contentContainer.topAnchor.constraint(equalTo: topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: sidebarBackground.trailingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Select first row
        sidebarTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        showSection(.general)
    }

    private func showSection(_ section: Section) {
        let contentView: NSView

        switch section {
        case .general:
            if generalSection == nil {
                generalSection = GeneralSection()
            }
            contentView = generalSection!

        case .accessories:
            if accessoriesSection == nil {
                accessoriesSection = AccessoriesSettingsView()
                if let data = menuData {
                    accessoriesSection?.configure(with: data)
                }
            }
            contentView = accessoriesSection!

        case .deeplinks:
            if deeplinksSection == nil {
                deeplinksSection = DeeplinksSection()
            }
            contentView = deeplinksSection!

        case .about:
            if aboutSection == nil {
                aboutSection = AboutSection()
            }
            contentView = aboutSection!
        }

        // Use flipped view as wrapper for proper top alignment
        let wrapper = FlippedView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: wrapper.bottomAnchor)
        ])

        contentContainer.documentView = wrapper
        wrapper.widthAnchor.constraint(equalTo: contentContainer.widthAnchor).isActive = true
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        Section.allCases.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let section = Section.allCases[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("SidebarCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(imageView)
            cell?.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cell?.addSubview(textField)
            cell?.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        cell?.imageView?.image = NSImage(systemSymbolName: section.icon, accessibilityDescription: section.title)
        cell?.imageView?.contentTintColor = .secondaryLabelColor
        cell?.textField?.stringValue = section.title
        cell?.textField?.font = .systemFont(ofSize: 13)

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard row >= 0, row < Section.allCases.count else { return }
        showSection(Section.allCases[row])
    }

    func selectSection(at index: Int) {
        guard index >= 0, index < Section.allCases.count else { return }
        sidebarTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        showSection(Section.allCases[index])
    }
}
