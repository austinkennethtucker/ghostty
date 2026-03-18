import SwiftUI

/// A custom tab bar rendered inside the window for internal tab mode.
/// This replaces native macOS window tabbing so that tiling window managers
/// like AeroSpace see a single window.
struct InternalTabBarView: View {
    @ObservedObject var tabManager: InternalTabManager
    let onNewTab: () -> Void
    let onCloseTab: (Int) -> Void
    let onSelectTab: (Int) -> Void

    @State private var hoveredTab: UUID?

    var body: some View {
        HStack(spacing: 0) {
            // Tab items in a scrollable area
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        InternalTabItemView(
                            tab: tab,
                            index: index,
                            isSelected: index == tabManager.selectedTabIndex,
                            isHovered: hoveredTab == tab.id,
                            onSelect: { onSelectTab(index) },
                            onClose: { onCloseTab(index) }
                        )
                        .onHover { isHovered in
                            hoveredTab = isHovered ? tab.id : nil
                        }
                    }
                }
                .padding(.leading, 4)
            }

            Spacer(minLength: 0)

            // New tab button
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            .help("New Tab")
        }
        .frame(height: 30)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

/// A single tab item in the internal tab bar.
private struct InternalTabItemView: View {
    let tab: InternalTabManager.Tab
    let index: Int
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Tab color indicator
            if tab.tabColor != .none, let color = tab.tabColor.displayColor {
                Circle()
                    .fill(Color(nsColor: color))
                    .frame(width: 8, height: 8)
            }

            // Tab title
            Text(tab.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? .primary : .secondary)

            // Keyboard shortcut indicator
            if index < 9 {
                Text("\u{2318}\(index + 1)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            // Close button (visible on hover or when selected)
            if isSelected || isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(minWidth: 80, maxWidth: 180)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                    ? Color(nsColor: .controlAccentColor).opacity(0.15)
                    : (isHovered ? Color(nsColor: .separatorColor).opacity(0.3) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
