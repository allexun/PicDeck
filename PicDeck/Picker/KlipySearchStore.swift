import Combine
import Foundation

@MainActor
final class KlipySearchStore: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var apiKey = ""
    @Published private(set) var isConfigured = false

    let configurationFileURL: URL

    private let client: KlipyClient
    private let pageSize = 24
    private var searchTask: Task<Void, Never>?
    private var currentQuery = ""
    private var currentPage = 1
    private var hasNext = false
    private var cachedResults: [String: KlipyCachedResult] = [:]

    init(configurationFileURL: URL, client: KlipyClient? = nil) {
        self.configurationFileURL = configurationFileURL
        self.client = client ?? KlipyClient()
        loadConfiguration()
    }

    func updateQuery(_ query: String) {
        let normalizedQuery = Self.normalizedQuery(query)
        searchTask?.cancel()

        guard isConfigured else {
            items = []
            errorMessage = "Enable Klipy and add an API key first."
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
            errorMessage = "Type at least 3 characters to search Klipy."
            return
        }

        currentQuery = normalizedQuery

        if let cachedResult = cachedResults[normalizedQuery] {
            items = cachedResult.items
            currentPage = cachedResult.nextPage
            hasNext = cachedResult.hasNext
            errorMessage = cachedResult.items.isEmpty ? "Nothing found on Klipy." : nil
            isLoading = false
            return
        }

        items = []
        currentPage = 1
        hasNext = false
        isLoading = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                try await self?.loadPage(query: normalizedQuery, page: 1, append: false)
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
            hasNext,
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
                let page = self?.currentPage ?? 1
                try await self?.loadPage(query: self?.currentQuery ?? "", page: page, append: true)
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
            throw KlipyConfigurationError.emptyAPIKey
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: configurationFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let payload = KlipyConfiguration(apiKey: normalizedKey)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: configurationFileURL, options: .atomic)

        self.apiKey = normalizedKey
        isConfigured = true
        cachedResults.removeAll()
        resetSearchState()
        errorMessage = nil
    }

    private func loadConfiguration() {
        do {
            let data = try Data(contentsOf: configurationFileURL)
            let configuration = try JSONDecoder().decode(KlipyConfiguration.self, from: data)
            apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            isConfigured = !apiKey.isEmpty
        } catch {
            apiKey = ""
            isConfigured = false
        }
    }

    private func loadPage(query: String, page: Int, append: Bool) async throws {
        let searchPage = try await client.searchGIFs(
            query: query,
            apiKey: apiKey,
            page: page,
            perPage: pageSize
        )

        guard !Task.isCancelled else {
            return
        }

        let newItems = searchPage.items.map(MediaItem.init(klipyGIF:))

        await MainActor.run {
            let mergedItems = append ? items + newItems : newItems

            items = mergedItems
            currentPage = page + 1
            hasNext = searchPage.hasNext
            cachedResults[query] = KlipyCachedResult(items: mergedItems, nextPage: page + 1, hasNext: searchPage.hasNext)
            isLoading = false
            isLoadingNextPage = false
            errorMessage = mergedItems.isEmpty ? "Nothing found on Klipy." : nil
        }
    }

    private func resetSearchState() {
        items = []
        isLoading = false
        isLoadingNextPage = false
        currentQuery = ""
        currentPage = 1
        hasNext = false
    }

    private static func normalizedQuery(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

private struct KlipyConfiguration: Codable {
    let apiKey: String
}

private struct KlipyCachedResult {
    let items: [MediaItem]
    let nextPage: Int
    let hasNext: Bool
}

enum KlipyConfigurationError: LocalizedError {
    case emptyAPIKey

    var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            "Enter a Klipy API key."
        }
    }
}
