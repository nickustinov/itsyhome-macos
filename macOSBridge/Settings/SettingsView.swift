//
//  SettingsView.swift
//  macOSBridge
//
//  Main settings view with sidebar navigation
//

import AppKit
import Combine

// Flipped view for proper top-to-bottom layout in scroll views
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// Custom row view with solid blue selection
class SidebarRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let selectionRect = bounds.insetBy(dx: 8, dy: 2)
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
        NSColor.systemBlue.setFill()
        path.fill()
    }

    override var isSelected: Bool {
        didSet {
            updateCellColors()
        }
    }

    private func updateCellColors() {
        for subview in subviews {
            updateColors(in: subview)
        }
    }

    private func updateColors(in view: NSView) {
        // Skip badge container (has blue background layer)
        if view.layer?.backgroundColor == NSColor.systemBlue.cgColor {
            return
        }

        for subview in view.subviews {
            if let imageView = subview as? NSImageView {
                imageView.contentTintColor = isSelected ? .white : .secondaryLabelColor
            } else if let textField = subview as? NSTextField {
                // Don't change PRO badge label colors
                if textField.stringValue != "PRO" {
                    textField.textColor = isSelected ? .white : .labelColor
                }
            }
            updateColors(in: subview)
        }
    }
}

class SettingsView: NSView, NSTableViewDataSource, NSTableViewDelegate {

    static let navigateToSectionNotification = Notification.Name("SettingsNavigateToSection")

    private let sidebarTableView = NSTableView()
    private let contentContainer = NSScrollView()

    private var menuData: MenuData?

    private enum Section: Int, CaseIterable {
        case general
        case homeAssistant
        case accessories
        case cameras
        case advanced
        case deeplinks
        case webhooks
        case itsytv
        case about

        var title: String {
            switch self {
            case .general: return String(localized: "settings.general.title", defaultValue: "General", bundle: .macOSBridge)
            case .homeAssistant: return String(localized: "settings.home_assistant.title", defaultValue: "Home Assistant", bundle: .macOSBridge)
            case .accessories: return String(localized: "settings.home.title", defaultValue: "Home", bundle: .macOSBridge)
            case .cameras: return String(localized: "settings.cameras.title", defaultValue: "Cameras", bundle: .macOSBridge)
            case .advanced: return String(localized: "settings.advanced.title", defaultValue: "Advanced", bundle: .macOSBridge)
            case .deeplinks: return String(localized: "settings.deeplinks.title", defaultValue: "Deeplinks", bundle: .macOSBridge)
            case .webhooks: return String(localized: "settings.webhooks.title", defaultValue: "Webhooks/CLI", bundle: .macOSBridge)
            case .itsytv: return String(localized: "settings.itsytv.title", defaultValue: "Apple TV remote", bundle: .macOSBridge)
            case .about: return String(localized: "settings.about.title", defaultValue: "About", bundle: .macOSBridge)
            }
        }

        var icon: String {
            switch self {
            case .general: return "gear"
            case .homeAssistant: return "plug"
            case .accessories: return "house"
            case .cameras: return "security-camera"
            case .advanced: return "sliders-horizontal"
            case .deeplinks: return "link"
            case .webhooks: return "globe"
            case .itsytv: return "television"
            case .about: return "info"
            }
        }

        var isProFeature: Bool {
            switch self {
            case .cameras, .deeplinks, .webhooks: return true
            default: return false
            }
        }

        /// Whether this section should be shown for the current platform
        var isAvailableForCurrentPlatform: Bool {
            let platform = PlatformManager.shared.selectedPlatform
            switch self {
            case .homeAssistant:
                return platform == .homeAssistant
            case .accessories:
                // Show Home section for both platforms (different content)
                return true
            default:
                return true
            }
        }

        /// Sections filtered for the current platform
        static var availableSections: [Section] {
            allCases.filter { $0.isAvailableForCurrentPlatform }
        }
    }

    // Content views (lazily created)
    private var generalSection: GeneralSection?
    private var homeAssistantSection: HomeAssistantSection?
    private var accessoriesSection: AccessoriesSettingsView?
    private var camerasSection: CamerasSection?
    private var advancedSection: AdvancedSection?
    private var deeplinksSection: DeeplinksSection?
    private var webhooksSection: WebhooksSection?
    private var itsytvSection: ItsytvSection?
    private var aboutSection: AboutSection?
    private var cancellables = Set<AnyCancellable>()

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
        camerasSection?.configure(with: data)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, sidebarTableView.selectedRow < 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.sidebarTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    private func setupView() {
        // Sidebar background
        let sidebarBackground = NSVisualEffectView()
        sidebarBackground.material = .sidebar
        sidebarBackground.blendingMode = .behindWindow
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

            // Sidebar scroll view (below title bar)
            sidebarScrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            sidebarScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarScrollView.widthAnchor.constraint(equalToConstant: 200),

            // Content (below title bar)
            contentContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: sidebarBackground.trailingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        showSection(.general)

        // Listen for section navigation requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigateToSection(_:)),
            name: Self.navigateToSectionNotification,
            object: nil
        )

        // Refresh Pro-gated sections when Pro status changes
        ProManager.shared.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleProStatusChanged() }
            .store(in: &cancellables)
    }

    @objc private func handleNavigateToSection(_ notification: Notification) {
        guard let index = notification.userInfo?["index"] as? Int else { return }
        selectSection(at: index)
    }

    private func handleProStatusChanged() {
        // Clear cached Pro-feature sections so they rebuild with new state
        camerasSection = nil
        deeplinksSection = nil
        webhooksSection = nil

        // Reload sidebar to update PRO badges
        let selectedRow = sidebarTableView.selectedRow
        sidebarTableView.reloadData()
        if selectedRow >= 0 {
            sidebarTableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        }

        // Re-show current section if it's a Pro section
        let row = sidebarTableView.selectedRow
        guard row >= 0, row < Section.availableSections.count else { return }
        let current = Section.availableSections[row]
        if current.isProFeature {
            showSection(current)
        }
    }

    private func showSection(_ section: Section) {
        let contentView: NSView

        switch section {
        case .general:
            if generalSection == nil {
                generalSection = GeneralSection()
            }
            contentView = generalSection!

        case .homeAssistant:
            if homeAssistantSection == nil {
                homeAssistantSection = HomeAssistantSection()
            }
            contentView = homeAssistantSection!

        case .accessories:
            if accessoriesSection == nil {
                accessoriesSection = AccessoriesSettingsView()
                if let data = menuData {
                    accessoriesSection?.configure(with: data)
                }
            }
            contentView = accessoriesSection!

        case .cameras:
            if camerasSection == nil {
                camerasSection = CamerasSection()
                if let data = menuData {
                    camerasSection?.configure(with: data)
                }
            }
            contentView = camerasSection!

        case .advanced:
            if advancedSection == nil {
                advancedSection = AdvancedSection()
            }
            contentView = advancedSection!

        case .deeplinks:
            if deeplinksSection == nil {
                deeplinksSection = DeeplinksSection()
            }
            contentView = deeplinksSection!

        case .webhooks:
            if webhooksSection == nil {
                webhooksSection = WebhooksSection()
            }
            contentView = webhooksSection!

        case .itsytv:
            if itsytvSection == nil {
                itsytvSection = ItsytvSection()
            }
            contentView = itsytvSection!

        case .about:
            if aboutSection == nil {
                aboutSection = AboutSection()
            }
            contentView = aboutSection!
        }

        // Use flipped view as wrapper for proper top alignment
        let wrapper = FlippedView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: section.title)
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(titleLabel)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(contentView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: wrapper.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -20),

            contentView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: wrapper.bottomAnchor)
        ])

        contentContainer.documentView = wrapper
        wrapper.widthAnchor.constraint(equalTo: contentContainer.widthAnchor).isActive = true
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        Section.availableSections.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return SidebarRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let section = Section.availableSections[row]

        // Create cell container
        let cell = NSView()

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = PhosphorIcon.regular(section.icon)
        imageView.contentTintColor = .secondaryLabelColor
        cell.addSubview(imageView)

        let textField = NSTextField(labelWithString: section.title)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        textField.font = .systemFont(ofSize: 13)
        textField.textColor = .labelColor
        textField.isBezeled = false
        textField.isEditable = false
        textField.drawsBackground = false
        cell.addSubview(textField)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18),
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        // Add PRO badge for pro features (only if user doesn't have PRO)
        if section.isProFeature && !ProStatusCache.shared.isPro {
            let badgeContainer = NSView()
            badgeContainer.translatesAutoresizingMaskIntoConstraints = false
            badgeContainer.wantsLayer = true
            badgeContainer.layer?.backgroundColor = NSColor.systemBlue.cgColor
            badgeContainer.layer?.cornerRadius = 3
            cell.addSubview(badgeContainer)

            let badgeLabel = NSTextField(labelWithString: "PRO")
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeLabel.font = .systemFont(ofSize: 8, weight: .bold)
            badgeLabel.textColor = .white
            badgeLabel.alignment = .center
            badgeLabel.isBezeled = false
            badgeLabel.isEditable = false
            badgeLabel.drawsBackground = false
            badgeContainer.addSubview(badgeLabel)

            NSLayoutConstraint.activate([
                badgeContainer.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 6),
                badgeContainer.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                badgeContainer.widthAnchor.constraint(equalToConstant: 28),
                badgeContainer.heightAnchor.constraint(equalToConstant: 14),
                badgeContainer.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),

                badgeLabel.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
                badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor)
            ])
        } else {
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4).isActive = true
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard row >= 0, row < Section.availableSections.count else { return }
        showSection(Section.availableSections[row])
    }

    func selectSection(at index: Int) {
        guard index >= 0, index < Section.availableSections.count else { return }
        sidebarTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        showSection(Section.availableSections[index])
    }
}
