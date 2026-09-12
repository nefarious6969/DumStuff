import Foundation

/// Loads an authenticated X user timeline with X API v2.
/// The bearer token and user ID must come from the app's approved OAuth flow.
struct XProvider: FeedProvider {
    let source: FeedSource = .x
    let userID: String
    let bearerToken: String
    let session: URLSession

    init(userID: String, bearerToken: String, session: URLSession = .shared) {
        self.userID = userID
        self.bearerToken = bearerToken
        self.session = session
    }

    func load() async throws -> [FeedItem] {
        guard !userID.isEmpty, !bearerToken.isEmpty else {
            throw ProviderError.missingConfiguration("Connect X with OAuth before loading this feed.")
        }
        guard let encodedID = userID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(string: "https://api.x.com/2/users/\(encodedID)/tweets") else {
            throw ProviderError.missingConfiguration("The X user ID is invalid.")
        }
        components.queryItems = [
            URLQueryItem(name: "max_results", value: "25"),
            URLQueryItem(name: "tweet.fields", value: "created_at,attachments,text"),
            URLQueryItem(name: "expansions", value: "attachments.media_keys"),
            URLQueryItem(name: "media.fields", value: "type,url,preview_image_url,variants")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let timeline = try JSONDecoder().decode(XTimelineResponse.self, from: data)
        let mediaByKey = Dictionary(uniqueKeysWithValues: (timeline.includes?.media ?? []).map { ($0.mediaKey, $0) })
        let formatter = ISO8601DateFormatter()

        return (timeline.data ?? []).map { tweet in
            let media = tweet.attachments?.mediaKeys?.compactMap { mediaByKey[$0] }.first
            let mediaURL = media?.url ?? media?.variants?.sorted { ($0.bitRate ?? 0) > ($1.bitRate ?? 0) }.first?.url
            let isVideo = media?.type == "video" || media?.type == "animated_gif"
            return FeedItem(
                source: .x,
                author: "@\(userID)",
                title: tweet.text,
                body: tweet.text,
                mediaKind: isVideo ? .video : .photo,
                mediaURL: mediaURL.flatMap { URL(string: $0) },
                previewURL: media?.previewImageURL.flatMap { URL(string: $0) },
                postedAt: tweet.createdAt.flatMap { formatter.date(from: $0) } ?? .now
            )
        }
    }
}

private struct XTimelineResponse: Decodable { let data: [XTweet]?; let includes: XIncludes? }
private struct XIncludes: Decodable { let media: [XMedia]? }
private struct XTweet: Decodable {
    let text: String
    let createdAt: String?
    let attachments: XAttachments?
    enum CodingKeys: String, CodingKey { case text, attachments, createdAt = "created_at" }
}
private struct XAttachments: Decodable { let mediaKeys: [String]?; enum CodingKeys: String, CodingKey { case mediaKeys = "media_keys" } }
private struct XMedia: Decodable {
    let mediaKey: String
    let type: String
    let url: String?
    let previewImageURL: String?
    let variants: [XVariant]?
    enum CodingKeys: String, CodingKey {
        case mediaKey = "media_key", type, url, variants
        case previewImageURL = "preview_image_url"
    }
}
private struct XVariant: Decodable { let url: String; let bitRate: Int?; enum CodingKeys: String, CodingKey { case url, bitRate = "bit_rate" } }
