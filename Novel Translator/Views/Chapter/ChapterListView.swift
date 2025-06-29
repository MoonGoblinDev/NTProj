import SwiftUI
import AppKit

// MARK: - AppKit NSTableView Integration

/// A custom NSTableCellView to display a single chapter row.
/// This gives us full control over layout and performance, similar to a UITableViewCell in UIKit.
fileprivate class ChapterTableCellView: NSTableCellView {
    // UI Components
    private let chapterNumberLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let lineCountLabel = NSTextField(labelWithString: "")
    private let unsavedIndicatorLabel = NSTextField(labelWithString: "􁜿 ")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // --- Configure Labels ---
        chapterNumberLabel.font = .systemFont(ofSize: 11)
        chapterNumberLabel.textColor = .secondaryLabelColor

        unsavedIndicatorLabel.font = .systemFont(ofSize: 13)

        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = .labelColor

        lineCountLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        lineCountLabel.alignment = .right
        
        // --- Layout with StackView ---
        let mainStack = NSStackView(views: [chapterNumberLabel, unsavedIndicatorLabel, titleLabel])
        mainStack.orientation = .horizontal
        mainStack.spacing = 2
        
        chapterNumberLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let containerStack = NSStackView(views: [mainStack, lineCountLabel])
        containerStack.orientation = .horizontal
        containerStack.distribution = .fill
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerStack)
        
        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 4),
            containerStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -4),
            containerStack.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }

    /// The main configuration method called by the table view delegate.
    func configure(chapter: Chapter, hasUnsavedChanges: Bool) {
        chapterNumberLabel.stringValue = "#\(chapter.chapterNumber)"
        titleLabel.stringValue = chapter.title
        lineCountLabel.stringValue = "\(chapter.translatedLineCount) / \(chapter.sourceLineCount)"

        // Update indicator visibility and color
        unsavedIndicatorLabel.isHidden = !hasUnsavedChanges
        if hasUnsavedChanges {
            unsavedIndicatorLabel.textColor = NSColor(Color.unsaved)
        }
        
        // Update line count color
        if chapter.translatedLineCount == 0 { lineCountLabel.textColor = .secondaryLabelColor }
        else if chapter.translatedLineCount > chapter.sourceLineCount { lineCountLabel.textColor = .systemRed }
        else if chapter.translatedLineCount < chapter.sourceLineCount { lineCountLabel.textColor = .systemOrange }
        else if chapter.translatedLineCount == chapter.sourceLineCount { lineCountLabel.textColor = .systemGreen }
        else { lineCountLabel.textColor = .secondaryLabelColor }
    }

    // This is crucial for making text color adapt when the row is selected.
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            // When the row is selected (.emphasized), change text to white.
            if backgroundStyle == .emphasized {
                titleLabel.textColor = .white
                chapterNumberLabel.textColor = .white
            } else {
                // Otherwise, use the default text color.
                titleLabel.textColor = .labelColor
                chapterNumberLabel.textColor = .secondaryLabelColor
            }
        }
    }
}


/// The NSViewRepresentable that wraps NSTableView for use in SwiftUI.
fileprivate struct ChapterTableView: NSViewRepresentable {
    // MARK: - Input from SwiftUI
    @ObservedObject var project: TranslationProject
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    
    // Using a direct binding to the sorted array managed by the parent SwiftUI view.
    @Binding var sortedChapters: [Chapter]

    // Callbacks to communicate events back to SwiftUI.
    var onSelect: (UUID) -> Void
    var onDelete: (IndexSet) -> Void

    // MARK: - Coordinator
    /// The coordinator acts as the delegate and data source for the NSTableView.
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - NSViewRepresentable Lifecycle
    
    /// Creates the NSTableView and its enclosing scroll view once.
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Give the coordinator a reference to the table view for robust actions.
        context.coordinator.tableView = tableView

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false // Let SwiftUI handle the background.

        tableView.headerView = nil
        tableView.style = .inset
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 2) // Add a little space between rows
        tableView.allowsMultipleSelection = false
        tableView.doubleAction = #selector(Coordinator.doubleClicked)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ChapterColumn"))
        column.isEditable = false
        tableView.addTableColumn(column)

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        
        // Set up context menu for deletion
        let menu = NSMenu()
        menu.addItem(withTitle: "Delete", action: #selector(Coordinator.deleteClicked(_:)), keyEquivalent: "").target = context.coordinator
        tableView.menu = menu
        
        return scrollView
    }

    /// Updates the NSTableView when SwiftUI state changes.
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }

        // Pass the latest state to the coordinator.
        context.coordinator.parent = self
        
        // This is the most important part. `reloadData()` is extremely fast in AppKit
        // and tells the table to re-query the coordinator for data.
        tableView.reloadData()
        
        // After reloading, ensure the selection in the table view matches the state from the ViewModel.
        if let activeID = workspaceViewModel.activeChapterID, let rowIndex = sortedChapters.firstIndex(where: { $0.id == activeID }) {
            // Only update the selection if it's different, to avoid potential loops.
            if tableView.selectedRow != rowIndex {
                tableView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(rowIndex)
            }
        } else {
            // If no chapter is active, deselect all rows.
            if tableView.selectedRow != -1 {
                tableView.deselectAll(nil)
            }
        }
    }

    // MARK: - Coordinator Implementation
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: ChapterTableView
        weak var tableView: NSTableView?

        init(parent: ChapterTableView) {
            self.parent = parent
        }

        // --- Data Source ---
        func numberOfRows(in tableView: NSTableView) -> Int {
            return parent.sortedChapters.count
        }

        // --- Delegate ---
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < parent.sortedChapters.count else { return nil }
            let chapter = parent.sortedChapters[row]
            
            let identifier = NSUserInterfaceItemIdentifier("ChapterCell")
            var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? ChapterTableCellView
            if cell == nil {
                cell = ChapterTableCellView(frame: .zero)
                cell?.identifier = identifier
            }
            
            let hasUnsaved = parent.workspaceViewModel.editorStates[chapter.id]?.hasUnsavedChanges ?? false
            cell?.configure(chapter: chapter, hasUnsavedChanges: hasUnsaved)
            
            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            // Custom row view to control selection color and appearance.
            let rowView = NSTableRowView()
            rowView.selectionHighlightStyle = .regular
            
            // Replicate the "open" but not "active" state background color
            if row < parent.sortedChapters.count {
                let chapter = parent.sortedChapters[row]
                if parent.workspaceViewModel.openChapterIDs.contains(chapter.id) &&
                   parent.workspaceViewModel.activeChapterID != chapter.id {
                    rowView.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.1)
                }
            }
            
            return rowView
        }
        
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            return 28 // Set a consistent row height
        }

        // --- Actions ---
        
        // MODIFIED: This is the critical fix.
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView,
                  tableView.selectedRow >= 0,
                  tableView.selectedRow < parent.sortedChapters.count else { return }

            let selectedID = parent.sortedChapters[tableView.selectedRow].id
            
            // Don't do anything if the state is already correct. This helps prevent loops.
            guard parent.workspaceViewModel.activeChapterID != selectedID else { return }

            // By dispatching this asynchronously to the main queue, we allow the current
            // view update cycle to finish before publishing the state change.
            // This resolves the "Publishing changes from within view updates" error.
            DispatchQueue.main.async {
                self.parent.onSelect(selectedID)
            }
        }
        
        @objc func doubleClicked(_ sender: AnyObject) {
            // Could be used for a future action, e.g., rename.
        }
        
        @objc func deleteClicked(_ sender: NSMenuItem) {
            // Now safely uses the weak reference to the table view.
            guard let tableView = self.tableView, tableView.clickedRow >= 0 else { return }
            parent.onDelete(IndexSet(integer: tableView.clickedRow))
        }
    }
}


// MARK: - Main SwiftUI View
/// This is the top-level SwiftUI view that now hosts our AppKit table view.
struct ChapterListView: View {
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    @ObservedObject var project: TranslationProject
    
    // The single source of truth for the sorted chapter list.
    // The `ChapterTableView` will read from this via a binding.
    @State private var sortedChapters: [Chapter] = []

    var body: some View {
        VStack(spacing: 0) {
            if sortedChapters.isEmpty {
                ContentUnavailableView(
                    "No Chapters",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Import your first chapter to begin.")
                )
                .frame(maxHeight: .infinity)
            } else {
                // Replace the SwiftUI `List` with our high-performance `ChapterTableView`.
                ChapterTableView(
                    project: project,
                    workspaceViewModel: workspaceViewModel,
                    sortedChapters: $sortedChapters,
                    onSelect: { chapterID in
                        // When a row is clicked in AppKit, this closure is called.
                        workspaceViewModel.openChapter(id: chapterID)
                    },
                    onDelete: { offsets in
                        // When delete is triggered from the context menu.
                        deleteChapters(at: offsets)
                    }
                )
            }
        }
        .onAppear {
            updateSortedChapters()
        }
        .onChange(of: project.chapters) {
            // Re-sort the list only when the underlying data changes.
            updateSortedChapters()
        }
        // MODIFIED: Monitor changes to open/active chapters to trigger a redraw of the AppKit table.
        // This is necessary to update row background colors and selection states
        // when they are changed by something other than a direct click (e.g., closing a tab).
        .onChange(of: workspaceViewModel.activeChapterID) { _, _ in }
        .onChange(of: workspaceViewModel.openChapterIDs) { _, _ in }
        .onChange(of: workspaceViewModel.hasUnsavedEditorChanges) { _, _ in }
    }

    private func updateSortedChapters() {
        // This is now the single place where sorting happens.
        sortedChapters = project.chapters.sorted { $0.chapterNumber < $1.chapterNumber }
    }

    private func deleteChapters(at offsets: IndexSet) {
        // The logic remains the same, but it's now triggered by the AppKit view's callback.
        let idsToDelete = offsets.map { sortedChapters[$0].id }
        
        for id in idsToDelete {
            workspaceViewModel.closeChapter(id: id)
            project.chapters.removeAll { $0.id == id }
        }
        // The `.onChange(of: project.chapters)` will automatically update the list.
    }
}
