import Foundation
import AppKit

/// A group of tabs within a single split pane. The SplitTree leaf always holds the
/// active surface; this model tracks the full set of surfaces in a pane tab group.
///
/// When a pane has only one tab (the common case), no PaneTabGroup exists for it.
/// PaneTabGroups are created on demand when new_pane_tab is triggered and removed
/// when closing tabs reduces the group to one surface.
class PaneTabGroup: ObservableObject, Codable, Identifiable {
    let id: UUID

    /// All surfaces in this tab group, in display order.
    @Published var tabs: [Ghostty.SurfaceView]

    /// Index of the currently active (visible) tab.
    @Published var activeIndex: Int

    var activeView: Ghostty.SurfaceView {
        tabs[activeIndex]
    }

    var tabCount: Int {
        tabs.count
    }

    init(surfaces: [Ghostty.SurfaceView], activeIndex: Int = 0) {
        self.id = UUID()
        self.tabs = surfaces
        self.activeIndex = min(activeIndex, max(surfaces.count - 1, 0))
    }

    /// Convenience: create from a single surface (starting point before adding tabs).
    convenience init(view: Ghostty.SurfaceView) {
        self.init(surfaces: [view], activeIndex: 0)
    }

    /// Add a new tab after the active tab and make it active. Returns the new active index.
    @discardableResult
    func addTab(_ surface: Ghostty.SurfaceView) -> Int {
        let insertPos = activeIndex + 1
        tabs.insert(surface, at: insertPos)
        activeIndex = insertPos
        return insertPos
    }

    /// Remove the tab at the given index. Returns the removed surface, or nil if out of bounds.
    @discardableResult
    func removeTab(at index: Int) -> Ghostty.SurfaceView? {
        guard index >= 0, index < tabs.count else { return nil }
        let removed = tabs.remove(at: index)

        if tabs.isEmpty {
            activeIndex = 0
        } else if activeIndex >= tabs.count {
            activeIndex = tabs.count - 1
        } else if index < activeIndex {
            activeIndex -= 1
        }

        return removed
    }

    /// Remove a specific surface from the group. Returns true if found and removed.
    @discardableResult
    func removeTab(surface: Ghostty.SurfaceView) -> Bool {
        guard let index = tabs.firstIndex(where: { $0 === surface }) else { return false }
        removeTab(at: index)
        return true
    }

    /// Set the active tab by index.
    func setActive(_ index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeIndex = index
    }

    /// Returns the index of a surface, or nil if not in this group.
    func index(of surface: Ghostty.SurfaceView) -> Int? {
        tabs.firstIndex(where: { $0 === surface })
    }

    /// Whether a surface belongs to this group.
    func contains(_ surface: Ghostty.SurfaceView) -> Bool {
        tabs.contains(where: { $0 === surface })
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, tabs, activeIndex
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.tabs = try container.decode([Ghostty.SurfaceView].self, forKey: .tabs)
        self.activeIndex = try container.decode(Int.self, forKey: .activeIndex)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tabs, forKey: .tabs)
        try container.encode(activeIndex, forKey: .activeIndex)
    }
}
