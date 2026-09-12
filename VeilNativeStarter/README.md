# Veil native iOS starter

This folder contains the native SwiftUI foundation for Veil’s media-first feed and local safety layer.

## What is included

- A media-first unified feed model with source, author, media type, and sensitivity metadata.
- A provider protocol so each supported source can be added independently.
- A public Reddit JSON provider and an authenticated X API v2 provider.
- A Vision/Core ML scanner interface for on-device sensitive-region detection.
- Blur, pixel, black-bar, and custom-cover rendering hooks.
- SwiftUI feed and media-card views with muted autoplay video.

## Real-feed limitation

X and Reddit are the first supported sources in this starter. Reddit’s public subreddit endpoint works without an account; a personalized Reddit home feed still needs Reddit OAuth. X timelines require an approved X API product and user authorization. Veil should never collect a social password or scrape a private feed.

## Next Xcode steps

1. Create a new iOS 16 SwiftUI app named `Veil` and add these files.
2. Add a Core ML image model to the target as `SensitiveRegions.mlmodelc`. Its output should provide region boxes and labels such as `breast`, `genitalia`, and `buttocks`.
3. For a public Reddit feed, construct `RedditProvider(subreddit: "pics")`. For X, construct `XProvider(userID: ..., bearerToken: ...)` only after completing the provider’s OAuth flow, then pass both providers into `FeedStore(providers:)`.
4. Attach `VideoSafetyMonitor` to each player item for live video frames. It samples locally every 0.4 seconds, which is roughly 2.5 frames per second and is a reasonable starting point for an iPhone 8 Plus. Photo previews already pass through `MediaSafetyViewModel` when a Core ML model is present.

Example provider wiring:

```swift
let providers: [FeedProvider] = [
    RedditProvider(subreddit: "pics"),
    XProvider(userID: xUserID, bearerToken: xAccessToken)
]
let store = FeedStore(providers: providers)
```

The source files are intentionally free of account credentials, third-party analytics, and cloud image uploads.
