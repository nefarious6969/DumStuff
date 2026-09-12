import SwiftUI

@main
struct VeilApp: App {
    // Replace the demo provider with RedditProvider and an OAuth-backed
    // XProvider once the connection screen has supplied their credentials.
    @StateObject private var feedStore = FeedStore()
    @StateObject private var safetySettings = SafetySettings()

    var body: some Scene {
        WindowGroup {
            UnifiedFeedView()
                .environmentObject(feedStore)
                .environmentObject(safetySettings)
        }
    }
}
