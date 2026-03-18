import Foundation
import Combine

/// Manages internal tabs within a single window. Each tab has its own split tree
/// and focused surface. This is used when `macos-tab-mode = internal` to avoid
/// creating separate NSWindows for each tab, which is necessary for compatibility
/// with tiling window managers like AeroSpace.
class InternalTabManager: ObservableObject {
    /// A single internal tab.
    struct Tab: Identifiable {
        let id = UUID()
        var splitTree: SplitTree<Ghostty.SurfaceView>
        var focusedSurface: Ghostty.SurfaceView?
        var title: String = "Terminal"
        var tabColor: TerminalTabColor = .none
    }

    /// All tabs managed by this manager.
    @Published var tabs: [Tab] = []

    /// The index of the currently selected tab.
    @Published var selectedTabIndex: Int = 0

    /// The currently selected tab, if any.
    var selectedTab: Tab? {
        guard selectedTabIndex >= 0, selectedTabIndex < tabs.count else { return nil }
        return tabs[selectedTabIndex]
    }

    /// The number of tabs.
    var count: Int { tabs.count }

    /// Create a new tab with the given split tree. Returns the index of the new tab.
    @discardableResult
    func addTab(tree: SplitTree<Ghostty.SurfaceView>, afterIndex: Int? = nil) -> Int {
        let tab = Tab(splitTree: tree)
        let insertIndex: Int
        if let afterIndex, afterIndex >= 0, afterIndex < tabs.count {
            insertIndex = afterIndex + 1
        } else {
            insertIndex = tabs.count
        }
        tabs.insert(tab, at: insertIndex)
        return insertIndex
    }

    /// Remove the tab at the given index. Returns the removed tab.
    @discardableResult
    func removeTab(at index: Int) -> Tab? {
        guard index >= 0, index < tabs.count else { return nil }
        let tab = tabs.remove(at: index)

        // Adjust selected index
        if tabs.isEmpty {
            selectedTabIndex = 0
        } else if selectedTabIndex >= tabs.count {
            selectedTabIndex = tabs.count - 1
        } else if selectedTabIndex > index {
            selectedTabIndex -= 1
        }

        return tab
    }

    /// Select the tab at the given index.
    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        selectedTabIndex = index
    }

    /// Select the next tab, wrapping around.
    func selectNextTab() {
        guard tabs.count > 1 else { return }
        selectedTabIndex = (selectedTabIndex + 1) % tabs.count
    }

    /// Select the previous tab, wrapping around.
    func selectPreviousTab() {
        guard tabs.count > 1 else { return }
        selectedTabIndex = (selectedTabIndex - 1 + tabs.count) % tabs.count
    }

    /// Move the tab at `from` by the given amount (positive = right, negative = left).
    func moveTab(from sourceIndex: Int, by amount: Int) {
        guard amount != 0 else { return }
        guard sourceIndex >= 0, sourceIndex < tabs.count else { return }

        let targetIndex: Int
        if amount < 0 {
            targetIndex = max(0, sourceIndex + amount)
        } else {
            targetIndex = min(tabs.count - 1, sourceIndex + amount)
        }

        guard targetIndex != sourceIndex else { return }

        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: targetIndex)

        // Keep selection following the moved tab
        if selectedTabIndex == sourceIndex {
            selectedTabIndex = targetIndex
        }
    }

    /// Update the split tree for the currently selected tab.
    func updateSelectedTree(_ tree: SplitTree<Ghostty.SurfaceView>) {
        guard selectedTabIndex >= 0, selectedTabIndex < tabs.count else { return }
        tabs[selectedTabIndex].splitTree = tree
    }

    /// Update the focused surface for the currently selected tab.
    func updateSelectedFocusedSurface(_ surface: Ghostty.SurfaceView?) {
        guard selectedTabIndex >= 0, selectedTabIndex < tabs.count else { return }
        tabs[selectedTabIndex].focusedSurface = surface
    }

    /// Update the title for the currently selected tab.
    func updateSelectedTitle(_ title: String) {
        guard selectedTabIndex >= 0, selectedTabIndex < tabs.count else { return }
        tabs[selectedTabIndex].title = title
    }

    /// Update the tab color for the tab at the given index.
    func updateTabColor(at index: Int, color: TerminalTabColor) {
        guard index >= 0, index < tabs.count else { return }
        tabs[index].tabColor = color
    }

    /// Remove all other tabs except the one at the given index.
    func closeOtherTabs(except index: Int) -> [Tab] {
        guard index >= 0, index < tabs.count else { return [] }
        let kept = tabs[index]
        let removed = tabs.enumerated().filter { $0.offset != index }.map { $0.element }
        tabs = [kept]
        selectedTabIndex = 0
        return removed
    }

    /// Remove all tabs to the right of the given index.
    func closeTabsToTheRight(of index: Int) -> [Tab] {
        guard index >= 0, index < tabs.count - 1 else { return [] }
        let removed = Array(tabs[(index + 1)...])
        tabs = Array(tabs[...index])
        if selectedTabIndex >= tabs.count {
            selectedTabIndex = tabs.count - 1
        }
        return removed
    }
}
