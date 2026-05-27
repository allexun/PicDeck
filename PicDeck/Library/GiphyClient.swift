import Foundation

struct GiphyClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchGIFs(query: String, apiKey: String, limit: Int = 24, offset: Int = 0) async throws -> GiphySearchPage {
        guard !apiKey.isEmpty else {
            return GiphySearchPage(items: [], totalCount: 0)
        }

        var components = URLComponents(string: "https://api.giphy.com/v1/gifs/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "rating", value: "pg-13"),
            URLQueryItem(name: "lang", value: "en")
        ]

        guard let url = components?.url else {
            throw GiphyClientError.invalidRequest
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GiphyClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw GiphyClientError.requestFailed(httpResponse.statusCode)
        }

        let payload = try JSONDecoder().decode(GiphySearchResponse.self, from: data)
        return GiphySearchPage(
            items: payload.data.compactMap(\.gif),
            totalCount: payload.pagination.totalCount
        )
    }
}

struct GiphySearchPage {
    let items: [GiphyGIF]
    let totalCount: Int
}

enum GiphyClientError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "Could not prepare the Giphy search request."
        case .invalidResponse:
            "Giphy returned an invalid response."
        case .requestFailed(let statusCode):
            "Giphy search failed with status \(statusCode)."
        }
    }
}

private struct GiphySearchResponse: Decodable {
    let data: [GiphyGIFPayload]
    let pagination: GiphyPaginationPayload
}

private struct GiphyGIFPayload: Decodable {
    let id: String
    let title: String
    let images: GiphyImagesPayload

    var gif: GiphyGIF? {
        guard
            let previewImageURL = URL(string: images.fixedWidthStill.url),
            let originalGIFURL = URL(string: images.original.url)
        else {
            return nil
        }

        return GiphyGIF(
            id: id,
            title: title,
            previewImageURL: previewImageURL,
            originalGIFURL: originalGIFURL
        )
    }
}

private struct GiphyImagesPayload: Decodable {
    let fixedWidthStill: GiphyImageVariantPayload
    let original: GiphyImageVariantPayload

    enum CodingKeys: String, CodingKey {
        case fixedWidthStill = "fixed_width_still"
        case original
    }
}

private struct GiphyImageVariantPayload: Decodable {
    let url: String
}

private struct GiphyPaginationPayload: Decodable {
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
    }
}
