import SwiftUI

struct PickerView: View {
    @ObservedObject var store: MediaLibraryStore
    @ObservedObject var selection: PickerSelection

    let onCancel: () -> Void
    let onImportFromClipboard: () throws -> MediaItem
    let onRename: (MediaItem) -> MediaItem?
    let onPaste: (MediaItem) -> Void

    @State private var searchText = ""
    @State private var importErrorMessage: String?
    @FocusState private var searchFieldIsFocused: Bool

    private let gridSpacing: CGFloat = 14
    private let thumbnailMinimumWidth: CGFloat = 116
    private let thumbnailMaximumWidth: CGFloat = 140

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: thumbnailMinimumWidth, maximum: thumbnailMaximumWidth),
                spacing: gridSpacing
            )
        ]
    }

    private var filteredItems: [MediaItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return store.items
        }

        return store.items.filter { item in
            item.filename.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            if let importErrorMessage {
                Text(importErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = store.errorMessage {
                ContentUnavailableView("Could not load library", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                ContentUnavailableView("No media found", systemImage: "photo", description: Text("Add images or GIFs to ~/Pictures/PicDeck Library/"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(filteredItems) { item in
                                MediaThumbnailView(
                                    item: item,
                                    isSelected: selection.selectedItem == item,
                                    onRename: {
                                        rename(item)
                                    }
                                )
                                .id(item.id)
                                .onTapGesture {
                                    selection.selectedItem = item
                                    onPaste(item)
                                }
                            }
                        }
                        .background {
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: GridWidthPreferenceKey.self, value: geometry.size.width)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onPreferenceChange(GridWidthPreferenceKey.self) { width in
                        updateColumnCount(for: width)
                    }
                    .onChange(of: selection.selectedItem) {
                        guard let item = selection.selectedItem else {
                            return
                        }

                        withAnimation(.easeInOut(duration: 0.16)) {
                            proxy.scrollTo(item.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(20)
        .onAppear {
            searchFieldIsFocused = true
            syncSelection()
        }
        .onChange(of: searchText) {
            syncSelection()
        }
        .onChange(of: store.items) {
            syncSelection()
        }
        .onChange(of: selection.renameRequest) {
            guard let item = selection.renameRequest else {
                return
            }

            selection.renameRequest = nil
            rename(item)
        }
        .onSubmit {
            if let item = selection.selectedItem {
                onPaste(item)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            searchField

            Button {
                importFromClipboard()
            } label: {
                Label("Import from Clipboard", systemImage: "doc.on.clipboard")
                    .frame(maxHeight: .infinity)
            }
            .background(.quaternary.opacity(0.65))
            .cornerRadius(8)
            .frame(maxHeight: .infinity)
        }.frame(height: 38)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search filenames", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFieldIsFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func importFromClipboard() {
        do {
            let item = try onImportFromClipboard()
            searchText = ""
            selection.selectedItem = item
            importErrorMessage = nil
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func rename(_ item: MediaItem) {
        selection.selectedItem = item

        guard let renamedItem = onRename(item) else {
            return
        }

        searchText = ""
        selection.selectedItem = renamedItem
    }

    private func syncSelection() {
        let items = filteredItems
        selection.visibleItems = items

        guard !items.isEmpty else {
            selection.selectedItem = nil
            return
        }

        if let selectedItem = selection.selectedItem, items.contains(selectedItem) {
            return
        }

        selection.selectedItem = items.first
    }

    private func updateColumnCount(for width: CGFloat) {
        guard width > 0 else {
            return
        }

        selection.columnCount = max(1, Int((width + gridSpacing) / (thumbnailMinimumWidth + gridSpacing)))
    }
}

private struct GridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
