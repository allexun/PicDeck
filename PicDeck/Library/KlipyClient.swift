import Foundation

struct KlipyClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchGIFs(query: String, apiKey: String, page: Int = 1, perPage: Int = 24) async throws -> KlipySearchPage {
        guard !apiKey.isEmpty else {
            return KlipySearchPage(items: [], hasNext: false)
        }

        guard
            let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            var components = URLComponents(string: "https://api.klipy.com/api/v1/\(encodedKey)/gifs/search")
        else {
            throw KlipyClientError.invalidRequest
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]

        guard let url = components.url else {
            throw KlipyClientError.invalidRequest
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KlipyClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw KlipyClientError.requestFailed(httpResponse.statusCode)
        }

        let payload = try JSONDecoder().decode(KlipySearchResponse.self, from: data)

        guard payload.result else {
            throw KlipyClientError.apiError
        }

        return KlipySearchPage(
            items: payload.data.data.compactMap(\.klipyGIF),
            hasNext: payload.data.hasNext
        )
    }
}

struct KlipySearchPage {
    let items: [KlipyGIF]
    let hasNext: Bool
}

enum KlipyClientError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case requestFailed(Int)
    case apiError

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "Could not prepare the Klipy search request."
        case .invalidResponse:
            "Klipy returned an invalid response."
        case .requestFailed(let statusCode):
            "Klipy search failed with status \(statusCode)."
        case .apiError:
            "Klipy returned an error. Check your API key."
        }
    }
}

private struct KlipySearchResponse: Decodable {
    let result: Bool
    let data: KlipySearchData
}

private struct KlipySearchData: Decodable {
    let data: [KlipyGIFPayload]
    let hasNext: Bool

    enum CodingKeys: String, CodingKey {
        case data
        case hasNext = "has_next"
    }
}

private struct KlipyGIFPayload: Decodable {
    let id: Int64
    let title: String
    let file: KlipyFilePayload

    var klipyGIF: KlipyGIF? {
        guard
            let previewURL = URL(string: file.xs.jpg.url),
            let originalURL = URL(string: file.hd.gif.url)
        else {
            return nil
        }

        return KlipyGIF(
            id: String(id),
            title: title,
            previewImageURL: previewURL,
            originalGIFURL: originalURL
        )
    }
}

private struct KlipyFilePayload: Decodable {
    let hd: KlipySizePayload
    let xs: KlipySizePayload
}

private struct KlipySizePayload: Decodable {
    let gif: KlipyMediaVariantPayload
    let jpg: KlipyMediaVariantPayload
}

private struct KlipyMediaVariantPayload: Decodable {
    let url: String
}
