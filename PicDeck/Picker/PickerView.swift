import SwiftUI

struct PickerView: View {
    @ObservedObject var store: MediaLibraryStore
    @ObservedObject var giphySearchStore: GiphySearchStore
    @ObservedObject var klipySearchStore: KlipySearchStore
    @ObservedObject var selection: PickerSelection

    let onCancel: () -> Void
    let onImportFromClipboard: () throws -> MediaItem
    let onRename: (MediaItem) -> MediaItem?
    let onPaste: (MediaItem) -> Void

    @State private var searchMode: SearchMode = .library
    @State private var searchText = ""
    @State private var importErrorMessage: String?
    @State private var giphyAPIKey = ""
    @State private var isShowingGiphySetup = false
    @State private var giphySetupErrorMessage: String?
    @State private var klipyAPIKey = ""
    @State private var isShowingKlipySetup = false
    @State private var klipySetupErrorMessage: String?
    @State private var previewedItem: MediaItem?
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

    private var localItems: [MediaItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return store.items
        }

        return store.items.filter { item in
            item.filename.localizedCaseInsensitiveContains(query)
        }
    }

    private var displayedItems: [MediaItem] {
        switch searchMode {
        case .library:
            localItems
        case .giphy:
            giphySearchStore.items
        case .klipy:
            klipySearchStore.items
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                header

                if let importErrorMessage {
                    Text(importErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                contentView
            }
            .padding(20)

            if let previewedItem {
                fullWindowPreview(previewedItem)
            }
        }
        .onAppear {
            searchFieldIsFocused = true
            syncSelection()
            updateRemoteSearchIfNeeded()
            giphyAPIKey = giphySearchStore.apiKey
            klipyAPIKey = klipySearchStore.apiKey
        }
        .onChange(of: searchText) {
            syncSelection()
            updateRemoteSearchIfNeeded()
        }
        .onChange(of: searchMode) {
            syncSelection()
            activateSearchMode()
        }
        .onChange(of: store.items) {
            syncSelection()
        }
        .onChange(of: giphySearchStore.items) {
            syncSelection()
        }
        .onChange(of: giphySearchStore.errorMessage) {
            syncSelection()
        }
        .onChange(of: klipySearchStore.items) {
            syncSelection()
        }
        .onChange(of: klipySearchStore.errorMessage) {
            syncSelection()
        }
        .onChange(of: selection.renameRequest) {
            guard let item = selection.renameRequest else {
                return
            }

            selection.renameRequest = nil
            rename(item)
        }
        .onChange(of: selection.searchModeSwitchRequest) {
            switchSearchMode()
        }
        .onChange(of: selection.previewRequest) {
            togglePreview()
        }
        .onSubmit {
            if let item = selection.selectedItem {
                onPaste(item)
            }
        }
        .sheet(isPresented: $isShowingGiphySetup) {
            giphySetupSheet
        }
        .sheet(isPresented: $isShowingKlipySetup) {
            klipySetupSheet
        }
    }

    private func fullWindowPreview(_ item: MediaItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.black.opacity(0.88))

            previewImageView(item)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                previewedItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            previewedItem = nil
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func previewImageView(_ item: MediaItem) -> some View {
        if item.isGIF {
            AnimatedMediaView(item: item)
        } else if let image = NSImage(contentsOf: item.url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "photo")
                .font(.system(size: 54))
                .foregroundStyle(.white.secondary)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Picker("Search mode", selection: $searchMode) {
                ForEach(SearchMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                searchField

                switch searchMode {
                case .library:
                    Button {
                        importFromClipboard()
                    } label: {
                        Label("Import from Clipboard", systemImage: "doc.on.clipboard")
                            .frame(maxHeight: .infinity)
                    }
                    .background(.quaternary.opacity(0.65))
                    .cornerRadius(8)
                    .frame(maxHeight: .infinity)
                case .giphy:
                    Button {
                        giphyAPIKey = giphySearchStore.apiKey
                        giphySetupErrorMessage = nil
                        isShowingGiphySetup = true
                    } label: {
                        Label("Giphy Key", systemImage: "key")
                            .frame(maxHeight: .infinity)
                    }
                    .background(.quaternary.opacity(0.65))
                    .cornerRadius(8)
                    .frame(maxHeight: .infinity)
                case .klipy:
                    Button {
                        klipyAPIKey = klipySearchStore.apiKey
                        klipySetupErrorMessage = nil
                        isShowingKlipySetup = true
                    } label: {
                        Label("Klipy Key", systemImage: "key")
                            .frame(maxHeight: .infinity)
                    }
                    .background(.quaternary.opacity(0.65))
                    .cornerRadius(8)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 38)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(searchMode.searchPlaceholder, text: $searchText)
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

    @ViewBuilder
    private var contentView: some View {
        if searchMode == .library, let errorMessage = store.errorMessage {
            errorView(
                title: "Could not load library",
                systemImage: "exclamationmark.triangle",
                description: errorMessage
            )
        } else if searchMode == .giphy, let errorMessage = giphySearchStore.errorMessage {
            errorView(
                title: "Giphy search",
                systemImage: "sparkles.tv",
                description: errorMessage
            )
        } else if searchMode == .giphy, giphySearchStore.isLoading {
            ProgressView("Searching Giphy...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if searchMode == .klipy, let errorMessage = klipySearchStore.errorMessage {
            errorView(
                title: "Klipy search",
                systemImage: "sparkles.tv",
                description: errorMessage
            )
        } else if searchMode == .klipy, klipySearchStore.isLoading {
            ProgressView("Searching Klipy...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayedItems.isEmpty {
            emptyStateView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            gridContentView
        }
    }

    private var gridContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(displayedItems) { item in
                        mediaItemView(item)
                    }
                }
                footerLoadingView
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

    @ViewBuilder
    private var footerLoadingView: some View {
        if searchMode == .giphy, giphySearchStore.isLoadingNextPage {
            ProgressView("Loading more GIFs...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } else if searchMode == .klipy, klipySearchStore.isLoadingNextPage {
            ProgressView("Loading more GIFs...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private func mediaItemView(_ item: MediaItem) -> some View {
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
        .onAppear {
            if searchMode == .giphy {
                giphySearchStore.loadNextPageIfNeeded(currentItem: item)
            } else if searchMode == .klipy {
                klipySearchStore.loadNextPageIfNeeded(currentItem: item)
            }
        }
    }

    private func errorView(title: String, systemImage: String, description: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        switch searchMode {
        case .library:
            ContentUnavailableView("No media found", systemImage: "photo", description: Text("Add images or GIFs to ~/Pictures/PicDeck Library/"))
        case .giphy:
            ContentUnavailableView("Search Giphy", systemImage: "sparkles.tv", description: Text("Type at least 3 characters. Requests are delayed and cached to avoid burning the API limit."))
        case .klipy:
            ContentUnavailableView("Search Klipy", systemImage: "sparkles.tv", description: Text("Type at least 3 characters. Requests are delayed and cached to avoid burning the API limit."))
        }
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
        let items = displayedItems
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

    private func updateRemoteSearchIfNeeded() {
        switch searchMode {
        case .library:
            break
        case .giphy:
            giphySearchStore.updateQuery(searchText)
        case .klipy:
            klipySearchStore.updateQuery(searchText)
        }
    }

    private func activateSearchMode() {
        switch searchMode {
        case .library:
            break
        case .giphy:
            if !giphySearchStore.isConfigured {
                giphyAPIKey = giphySearchStore.apiKey
                giphySetupErrorMessage = nil
                isShowingGiphySetup = true
            } else {
                updateRemoteSearchIfNeeded()
            }
        case .klipy:
            if !klipySearchStore.isConfigured {
                klipyAPIKey = klipySearchStore.apiKey
                klipySetupErrorMessage = nil
                isShowingKlipySetup = true
            } else {
                updateRemoteSearchIfNeeded()
            }
        }
    }

    private func switchSearchMode() {
        switch searchMode {
        case .library: searchMode = .giphy
        case .giphy: searchMode = .klipy
        case .klipy: searchMode = .library
        }
        searchFieldIsFocused = true
    }

    private func togglePreview() {
        guard let selectedItem = selection.selectedItem else {
            previewedItem = nil
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            previewedItem = previewedItem == selectedItem ? nil : selectedItem
        }
    }

    private var giphySetupSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enable Giphy Search")
                .font(.title3.weight(.semibold))

            Text("Add your Giphy API key once. PicDeck will store it in a JSON file inside `~/Pictures/PicDeck Library/` and reuse it on the next launch.")
                .foregroundStyle(.secondary)

            TextField("Giphy API key", text: $giphyAPIKey)
                .textFieldStyle(.roundedBorder)

            if let giphySetupErrorMessage {
                Text(giphySetupErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    if !giphySearchStore.isConfigured {
                        searchMode = .library
                    }

                    isShowingGiphySetup = false
                }

                Button("Save") {
                    saveGiphyAPIKey()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func saveGiphyAPIKey() {
        do {
            try giphySearchStore.saveAPIKey(giphyAPIKey)
            giphySetupErrorMessage = nil
            isShowingGiphySetup = false
            updateRemoteSearchIfNeeded()
        } catch {
            giphySetupErrorMessage = error.localizedDescription
        }
    }

    private var klipySetupSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enable Klipy Search")
                .font(.title3.weight(.semibold))

            Text("Add your Klipy API key once. PicDeck will store it in a JSON file inside `~/Pictures/PicDeck Library/` and reuse it on the next launch.")
                .foregroundStyle(.secondary)

            TextField("Klipy API key", text: $klipyAPIKey)
                .textFieldStyle(.roundedBorder)

            if let klipySetupErrorMessage {
                Text(klipySetupErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    if !klipySearchStore.isConfigured {
                        searchMode = .library
                    }

                    isShowingKlipySetup = false
                }

                Button("Save") {
                    saveKlipyAPIKey()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func saveKlipyAPIKey() {
        do {
            try klipySearchStore.saveAPIKey(klipyAPIKey)
            klipySetupErrorMessage = nil
            isShowingKlipySetup = false
            updateRemoteSearchIfNeeded()
        } catch {
            klipySetupErrorMessage = error.localizedDescription
        }
    }
}

private enum SearchMode: String, CaseIterable, Identifiable {
    case library
    case giphy
    case klipy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library:
            "Library"
        case .giphy:
            "Giphy"
        case .klipy:
            "Klipy"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .library:
            "Search filenames"
        case .giphy:
            "Search Giphy GIFs"
        case .klipy:
            "Search Klipy GIFs"
        }
    }
}

private struct GridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
