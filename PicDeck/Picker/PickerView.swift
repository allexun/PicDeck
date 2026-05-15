import SwiftUI

struct PickerView: View {
    @ObservedObject var store: MediaLibraryStore
    @ObservedObject var selection: PickerSelection

    let onCancel: () -> Void
    let onImportFromClipboard: () throws -> MediaItem
    let onPaste: (MediaItem) -> Void

    @State private var searchText = ""
    @State private var importErrorMessage: String?
    @FocusState private var searchFieldIsFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 116, maximum: 140), spacing: 14)
    ]

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
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredItems) { item in
                            MediaThumbnailView(
                                item: item,
                                isSelected: selection.selectedItem == item
                            )
                            .onTapGesture {
                                selection.selectedItem = item
                                onPaste(item)
                            }
                        }
                    }
                    .padding(.vertical, 2)
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

    private func syncSelection() {
        let items = filteredItems

        guard !items.isEmpty else {
            selection.selectedItem = nil
            return
        }

        if let selectedItem = selection.selectedItem, items.contains(selectedItem) {
            return
        }

        selection.selectedItem = items.first
    }
}
