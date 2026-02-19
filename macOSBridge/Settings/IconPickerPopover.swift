//
//  IconPickerPopover.swift
//  macOSBridge
//
//  Popover for selecting custom icons for accessories, scenes, and groups
//

import AppKit

// MARK: - Delegate protocol

protocol IconPickerPopoverDelegate: AnyObject {
    func iconPicker(_ picker: IconPickerPopover, didSelectIcon iconName: String?)
}

// MARK: - Icon picker popover

class IconPickerPopover: NSViewController {

    // MARK: - Configuration

    private let itemId: String
    private let serviceType: String?
    private let itemType: ItemType
    private let currentIconName: String?

    enum ItemType {
        case service
        case scene
        case group
        case room
    }

    weak var delegate: IconPickerPopoverDelegate?

    // MARK: - UI

    private let searchField = NSSearchField()
    private let suggestedLabel = NSTextField(labelWithString: "Suggested")
    private let suggestedStack = NSStackView()
    private let separatorLine = NSBox()
    private let allLabel = NSTextField(labelWithString: "All icons")
    private let scrollView = NSScrollView()
    private let iconsCollectionView: NSCollectionView
    private let resetButton = NSButton(title: String(localized: "shortcut.reset_icon", defaultValue: "Reset to default", bundle: .macOSBridge), target: nil, action: nil)

    // MARK: - Data

    private var allIconNames: [String] = []
    private var filteredIconNames: [String] = []
    private var suggestedIconNames: [String] = []

    // MARK: - Layout constants

    private let popoverWidth: CGFloat = 280
    private let popoverHeight: CGFloat = 380
    private let iconSize: CGFloat = 28
    private let iconsPerRow: Int = 8
    private let padding: CGFloat = 12
    private let spacing: CGFloat = 8

    // MARK: - Initialization

    init(itemId: String, serviceType: String?, itemType: ItemType = .service, itemName: String? = nil) {
        self.itemId = itemId
        self.serviceType = serviceType
        self.itemType = itemType
        self.currentIconName = PreferencesManager.shared.customIcon(for: itemId)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 28, height: 28)
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        layout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        iconsCollectionView = NSCollectionView()
        iconsCollectionView.collectionViewLayout = layout

        super.init(nibName: nil, bundle: nil)

        // Determine suggested icons based on type
        switch itemType {
        case .service:
            if let type = serviceType {
                suggestedIconNames = PhosphorIcon.suggestedIcons(for: type)
            }
        case .scene:
            suggestedIconNames = PhosphorIcon.suggestedSceneIcons
        case .group:
            suggestedIconNames = PhosphorIcon.suggestedGroupIcons
        case .room:
            suggestedIconNames = PhosphorIcon.suggestedRoomIcons
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        allIconNames = PhosphorIcon.allIconNames()
        filteredIconNames = allIconNames

        setupUI()
        updateSuggestedIcons()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Search field
        searchField.placeholderString = "Search icons"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        view.addSubview(searchField)

        // Suggested label
        suggestedLabel.font = .systemFont(ofSize: 11, weight: .medium)
        suggestedLabel.textColor = .secondaryLabelColor
        suggestedLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestedLabel)

        // Suggested icons stack
        suggestedStack.orientation = .horizontal
        suggestedStack.spacing = 4
        suggestedStack.alignment = .centerY
        suggestedStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestedStack)

        // Separator
        separatorLine.boxType = .separator
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separatorLine)

        // All icons label
        allLabel.font = .systemFont(ofSize: 11, weight: .medium)
        allLabel.textColor = .secondaryLabelColor
        allLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(allLabel)

        // Collection view setup
        iconsCollectionView.register(IconCollectionViewItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("IconItem"))
        iconsCollectionView.dataSource = self
        iconsCollectionView.delegate = self
        iconsCollectionView.backgroundColors = [.clear]
        iconsCollectionView.isSelectable = true

        scrollView.documentView = iconsCollectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Reset button
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .small
        resetButton.target = self
        resetButton.action = #selector(resetTapped)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.isHidden = currentIconName == nil
        view.addSubview(resetButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),

            suggestedLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: spacing),
            suggestedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),

            suggestedStack.topAnchor.constraint(equalTo: suggestedLabel.bottomAnchor, constant: 4),
            suggestedStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            suggestedStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -padding),

            separatorLine.topAnchor.constraint(equalTo: suggestedStack.bottomAnchor, constant: spacing),
            separatorLine.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            separatorLine.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),

            allLabel.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: spacing),
            allLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),

            scrollView.topAnchor.constraint(equalTo: allLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            scrollView.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -spacing),

            resetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            resetButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding)
        ])

        // Set collection view width constraint
        let collectionWidth = popoverWidth - (padding * 2)
        iconsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconsCollectionView.widthAnchor.constraint(equalToConstant: collectionWidth)
        ])
    }

    private func updateSuggestedIcons() {
        suggestedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let iconsToShow = Array(suggestedIconNames.prefix(8))
        for iconName in iconsToShow {
            let button = createIconButton(iconName: iconName)
            suggestedStack.addArrangedSubview(button)
        }

        let hasSuggestions = !iconsToShow.isEmpty
        suggestedLabel.isHidden = !hasSuggestions
        suggestedStack.isHidden = !hasSuggestions
        separatorLine.isHidden = !hasSuggestions
    }

    private func createIconButton(iconName: String) -> NSView {
        // Use a container view with an image view for clean appearance (no bevel)
        let containerSize: CGFloat = 28
        let iconDisplaySize: CGFloat = 20

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        imageView.image = PhosphorIcon.regular(iconName)
        imageView.contentTintColor = iconName == currentIconName ? .controlAccentColor : .secondaryLabelColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: containerSize),
            container.heightAnchor.constraint(equalToConstant: containerSize),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: iconDisplaySize),
            imageView.heightAnchor.constraint(equalToConstant: iconDisplaySize)
        ])

        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(suggestedIconClicked(_:)))
        container.addGestureRecognizer(clickGesture)
        container.identifier = NSUserInterfaceItemIdentifier(iconName)

        return container
    }

    @objc private func suggestedIconClicked(_ gesture: NSClickGestureRecognizer) {
        guard let iconName = gesture.view?.identifier?.rawValue else { return }
        selectIcon(iconName)
    }

    // MARK: - Actions

    @objc private func resetTapped() {
        PreferencesManager.shared.setCustomIcon(nil, for: itemId)
        delegate?.iconPicker(self, didSelectIcon: nil)
        dismissPopover()
    }

    private func selectIcon(_ iconName: String) {
        PreferencesManager.shared.setCustomIcon(iconName, for: itemId)
        delegate?.iconPicker(self, didSelectIcon: iconName)
        dismissPopover()
    }

    private func dismissPopover() {
        if let popover = view.window?.parent as? NSPopover {
            popover.close()
        } else {
            dismiss(nil)
        }
    }

    private func filterIcons(with searchText: String) {
        if searchText.isEmpty {
            filteredIconNames = allIconNames
        } else {
            let lowercasedSearch = searchText.lowercased()
            filteredIconNames = allIconNames.filter { $0.lowercased().contains(lowercasedSearch) }
        }
        iconsCollectionView.reloadData()
    }
}

// MARK: - NSSearchFieldDelegate

extension IconPickerPopover: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filterIcons(with: searchField.stringValue)
    }
}

// MARK: - NSCollectionViewDataSource

extension IconPickerPopover: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredIconNames.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("IconItem"), for: indexPath)
        if let iconItem = item as? IconCollectionViewItem {
            let iconName = filteredIconNames[indexPath.item]
            iconItem.configure(iconName: iconName, isSelected: iconName == currentIconName)
        }
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension IconPickerPopover: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let iconName = filteredIconNames[indexPath.item]
        selectIcon(iconName)
    }
}

// MARK: - Icon collection view item

class IconCollectionViewItem: NSCollectionViewItem {

    private let iconImageView = NSImageView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))

        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(iconName: String, isSelected: Bool) {
        iconImageView.image = PhosphorIcon.regular(iconName)
        iconImageView.contentTintColor = isSelected ? .controlAccentColor : .secondaryLabelColor
    }

    override var isSelected: Bool {
        didSet {
            iconImageView.contentTintColor = isSelected ? .controlAccentColor : .secondaryLabelColor
        }
    }
}
