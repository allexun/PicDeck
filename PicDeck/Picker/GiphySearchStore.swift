import Combine
import Foundation

@MainActor
final class GiphySearchStore: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var apiKey = ""
    @Published private(set) var isConfigured = false

    let configurationFileURL: URL

    private let client: GiphyClient
    private let pageSize = 24
    private var searchTask: Task<Void, Never>?
    private var currentQuery = ""
    private var currentOffset = 0
    private var totalCount = 0
    private var canLoadMore = false
    private var cachedResults: [String: GiphyCachedResult] = [:]

    init(
        configurationFileURL: URL,
        client: GiphyClient? = nil
    ) {
        self.configurationFileURL = configurationFileURL
        self.client = client ?? GiphyClient()
        loadConfiguration()
    }

    func updateQuery(_ query: String) {
        let normalizedQuery = Self.normalizedQuery(query)
        searchTask?.cancel()

        guard isConfigured else {
            items = []
            errorMessage = "Enable Giphy and add an API key first."
            isLoading = false
            return
        }

        guard !normalizedQuery.isEmpty else {
            resetSearchState()
            errorMessage = nil
            return
        }

        guard normalizedQuery.count >= 3 else {
            resetSearchState()
            errorMessage = "Type at least 3 characters to search Giphy."
            return
        }

        currentQuery = normalizedQuery

        if let cachedResult = cachedResults[normalizedQuery] {
            items = cachedResult.items
            currentOffset = cachedResult.items.count
            totalCount = cachedResult.totalCount
            canLoadMore = cachedResult.items.count < cachedResult.totalCount
            errorMessage = cachedResult.items.isEmpty ? "Nothing found on Giphy." : nil
            isLoading = false
            return
        }

        items = []
        currentOffset = 0
        totalCount = 0
        canLoadMore = false
        isLoading = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                try await self?.loadPage(query: normalizedQuery, offset: 0, append: false)
            } catch is CancellationError {
                await MainActor.run {
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.items = []
                    self?.isLoading = false
                    self?.isLoadingNextPage = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadNextPageIfNeeded(currentItem: MediaItem) {
        guard
            isConfigured,
            canLoadMore,
            !isLoading,
            !isLoadingNextPage,
            currentItem.id == items.suffix(6).first?.id,
            !currentQuery.isEmpty
        else {
            return
        }

        isLoadingNextPage = true

        Task { [weak self] in
            do {
                try await self?.loadPage(query: self?.currentQuery ?? "", offset: self?.currentOffset ?? 0, append: true)
            } catch {
                await MainActor.run {
                    self?.isLoadingNextPage = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func saveAPIKey(_ apiKey: String) throws {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw GiphyConfigurationError.emptyAPIKey
        }

        let fileManager = FileManager.default

        try fileManager.createDirectory(
            at: configurationFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let payload = GiphyConfiguration(apiKey: normalizedKey)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: configurationFileURL, options: .atomic)

        self.apiKey = normalizedKey
        isConfigured = !normalizedKey.isEmpty
        cachedResults.removeAll()
        resetSearchState()
        errorMessage = nil
    }

    private func loadConfiguration() {
        do {
            let data = try Data(contentsOf: configurationFileURL)
            let configuration = try JSONDecoder().decode(GiphyConfiguration.self, from: data)
            apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            isConfigured = !apiKey.isEmpty
        } catch {
            apiKey = ""
            isConfigured = false
        }
    }

    private func loadPage(query: String, offset: Int, append: Bool) async throws {
        let page = try await client.searchGIFs(
            query: query,
            apiKey: apiKey,
            limit: pageSize,
            offset: offset
        )

        guard !Task.isCancelled else {
            return
        }

        let newItems = page.items.map(MediaItem.init(giphyGIF:))

        await MainActor.run {
            let mergedItems = append ? items + newItems : newItems

            items = mergedItems
            currentOffset = mergedItems.count
            totalCount = page.totalCount
            canLoadMore = mergedItems.count < page.totalCount
            cachedResults[query] = GiphyCachedResult(items: mergedItems, totalCount: page.totalCount)
            isLoading = false
            isLoadingNextPage = false
            errorMessage = mergedItems.isEmpty ? "Nothing found on Giphy." : nil
        }
    }

    private func resetSearchState() {
        items = []
        isLoading = false
        isLoadingNextPage = false
        currentQuery = ""
        currentOffset = 0
        totalCount = 0
        canLoadMore = false
    }

    private static func normalizedQuery(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

private struct GiphyConfiguration: Codable {
    let apiKey: String
}

private struct GiphyCachedResult {
    let items: [MediaItem]
    let totalCount: Int
}

enum GiphyConfigurationError: LocalizedError {
    case emptyAPIKey

    var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            "Enter a Giphy API key."
        }
    }
}
