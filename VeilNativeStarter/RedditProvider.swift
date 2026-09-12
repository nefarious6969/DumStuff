import Foundation

/// Loads a public subreddit listing through Reddit's documented JSON endpoint.
/// A personalized home feed should use Reddit OAuth instead of a stored password.
struct RedditProvider: FeedProvider {
    let source: FeedSource = .reddit
    let subreddit: String
    let session: URLSession

    init(subreddit: String = "popular", session: URLSession = .shared) {
        self.subreddit = subreddit.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.session = session
    }

    func load() async throws -> [FeedItem] {
        guard !subreddit.isEmpty,
              let url = URL(string: "https://www.reddit.com/r/\(subreddit)/hot.json?raw_json=1&limit=25") else {
            throw ProviderError.missingConfiguration("Choose a Reddit subreddit first.")
        }

        var request = URLRequest(url: url)
        request.setValue("Veil/1.0 (iOS media reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let listing = try JSONDecoder().decode(RedditListing.self, from: data)
        return listing.data.children.compactMap { child in
            let post = child.data
            guard !post.isStickied else { return nil }

            let videoURL = post.media?.redditVideo?.fallbackURL.flatMap { URL(string: $0) }
            let destinationURL = post.urlOverriddenByDest.flatMap { URL(string: $0) }
            let previewURL = post.preview?.images.first?.source.url
                .map { $0.replacingOccurrences(of: "&amp;", with: "&") }
                .flatMap { URL(string: $0) }
            let isVideo = post.isVideo || post.postHint == "hosted:video" || videoURL != nil
            let mediaURL = videoURL ?? destinationURL ?? previewURL
            let body = post.selftext.trimmingCharacters(in: .whitespacesAndNewlines)

            return FeedItem(
                id: UUID(uuidString: post.id) ?? UUID(),
                source: .reddit,
                author: "u/\(post.author ?? "[deleted]")",
                title: post.title,
                body: body.isEmpty ? "r/\(subreddit)" : body,
                mediaKind: isVideo ? .video : .photo,
                mediaURL: mediaURL,
                previewURL: previewURL,
                postedAt: Date(timeIntervalSince1970: post.createdUTC),
                isSensitive: post.over18
            )
        }
    }
}

private struct RedditListing: Decodable { let data: RedditListingData }
private struct RedditListingData: Decodable { let children: [RedditChild] }
private struct RedditChild: Decodable { let data: RedditPost }

private struct RedditPost: Decodable {
    let id: String
    let title: String
    let author: String?
    let selftext: String
    let urlOverriddenByDest: String?
    let postHint: String?
    let thumbnail: String?
    let preview: RedditPreview?
    let isVideo: Bool
    let media: RedditMedia?
    let createdUTC: Double
    let over18: Bool
    let isStickied: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, author, selftext, postHint = "post_hint"
        case urlOverriddenByDest = "url_overridden_by_dest"
        case thumbnail, preview, isVideo = "is_video", media
        case createdUTC = "created_utc", over18 = "over_18"
        case isStickied = "stickied"
    }
}

private struct RedditPreview: Decodable { let images: [RedditPreviewImage] }
private struct RedditPreviewImage: Decodable { let source: RedditImageSource }
private struct RedditImageSource: Decodable { let url: String }
private struct RedditMedia: Decodable { let redditVideo: RedditVideo?; enum CodingKeys: String, CodingKey { case redditVideo = "reddit_video" } }
private struct RedditVideo: Decodable { let fallbackURL: String?; enum CodingKeys: String, CodingKey { case fallbackURL = "fallback_url" } }
