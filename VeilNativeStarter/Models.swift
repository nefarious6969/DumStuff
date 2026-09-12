import Foundation
import CoreGraphics

enum FeedSource: String, CaseIterable, Codable, Identifiable {
    case all = "All"
    case x = "X"
    case reddit = "Reddit"

    var id: String { rawValue }
}

enum MediaKind: String, Codable {
    case photo
    case video
}

struct FeedItem: Identifiable, Codable, Equatable {
    let id: UUID
    let source: FeedSource
    let author: String
    let title: String
    let body: String
    let mediaKind: MediaKind
    let mediaURL: URL?
    let previewURL: URL?
    let postedAt: Date
    var isSensitive: Bool
    var isFollowing: Bool
    var isSaved: Bool

    init(id: UUID = UUID(), source: FeedSource, author: String, title: String, body: String, mediaKind: MediaKind, mediaURL: URL? = nil, previewURL: URL? = nil, postedAt: Date = .now, isSensitive: Bool = false, isFollowing: Bool = false, isSaved: Bool = false) {
        self.id = id
        self.source = source
        self.author = author
        self.title = title
        self.body = body
        self.mediaKind = mediaKind
        self.mediaURL = mediaURL
        self.previewURL = previewURL
        self.postedAt = postedAt
        self.isSensitive = isSensitive
        self.isFollowing = isFollowing
        self.isSaved = isSaved
    }
}

struct SensitiveRegion: Equatable {
    let label: String
    let bounds: CGRect
    let confidence: Float
}
