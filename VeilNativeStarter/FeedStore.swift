import Foundation
import Combine

protocol FeedProvider {
    var source: FeedSource { get }
    func load() async throws -> [FeedItem]
}

@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published var selectedSource: FeedSource = .all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let providers: [FeedProvider]

    init(providers: [FeedProvider] = [DemoProvider()]) {
        self.providers = providers
        items = DemoProvider.items
    }

    var visibleItems: [FeedItem] {
        items.filter { selectedSource == .all || $0.source == selectedSource }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            var loaded: [FeedItem] = []
            for provider in providers {
                loaded += try await provider.load()
            }
            if !loaded.isEmpty { items = loaded }
        } catch {
            errorMessage = "Some sources could not be refreshed."
        }
        isLoading = false
    }

    func toggleSaved(_ item: FeedItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isSaved.toggle()
    }
}

struct DemoProvider: FeedProvider {
    let source: FeedSource = .x

    static let items: [FeedItem] = [
        FeedItem(source: .x, author: "@fieldnotes", title: "A slower way to make a morning", body: "A quiet field recording and a short walk through the first light.", mediaKind: .video, mediaURL: URL(string: "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4"), isFollowing: true),
        FeedItem(source: .x, author: "@designsystems", title: "The interface should get out of the way", body: "A thread on making navigation feel obvious without making it loud.", mediaKind: .video, mediaURL: URL(string: "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4"), isSaved: true),
        FeedItem(source: .reddit, author: "u/photographer", title: "A quiet corner of the city", body: "r/photography", mediaKind: .photo, isFollowing: true),
        FeedItem(source: .reddit, author: "u/community", title: "Community post awaiting review", body: "r/pics", mediaKind: .photo, isSensitive: true),
    ]

    func load() async throws -> [FeedItem] { Self.items }
}
