import SwiftUI
import AVKit
import UIKit

struct ProtectedMediaView: View {
    let item: FeedItem
    @EnvironmentObject private var settings: SafetySettings
    @State private var revealed = false
    @State private var videoSensitive = false
    @StateObject private var safety = MediaSafetyViewModel()

    var body: some View {
        ZStack {
            media
            if settings.isEnabled && (item.isSensitive || videoSensitive || !safety.regions.isEmpty) && !revealed {
                cover
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(item.mediaKind == .video ? "AUTOPLAY · MUTED" : "PHOTO")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.black.opacity(0.72), in: Capsule())
                .padding(12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if settings.isEnabled && (item.isSensitive || videoSensitive || !safety.regions.isEmpty) { revealed = true }
        }
        .task(id: item.previewURL ?? item.mediaURL) {
            safety.scan(url: item.previewURL ?? item.mediaURL)
        }
    }

    @ViewBuilder private var media: some View {
        if item.mediaKind == .video, let url = item.mediaURL {
            AutoPlayVideoView(url: url) { detected in videoSensitive = detected }
        } else if let url = item.mediaURL ?? item.previewURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: LinearGradient(colors: [.purple.opacity(0.7), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        } else {
            LinearGradient(colors: [.purple.opacity(0.7), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Circle().fill(.white.opacity(0.13)).frame(width: 220).offset(x: 90, y: -100))
        }
    }

    private var cover: some View {
        ZStack {
            switch settings.coverStyle {
            case .blur: Rectangle().fill(.black.opacity(0.34)).background(.thinMaterial)
            case .pixel: Rectangle().fill(.black.opacity(0.78)).overlay(Text("PIXELATED").font(.caption.weight(.semibold)))
            case .bar: Rectangle().fill(.clear).overlay(Rectangle().fill(.black).frame(height: 66))
            case .custom:
                Rectangle().fill(.black.opacity(0.28))
                    .overlay {
                        if let data = settings.customImageData, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFit().padding(24)
                        } else {
                            Text(settings.coverText).font(.headline)
                        }
                    }
            }
            VStack(spacing: 5) { Text("Sensitive content hidden").font(.subheadline.weight(.semibold)); Text("Tap to reveal").font(.caption).foregroundStyle(.secondary) }
                .padding(14).background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct AutoPlayVideoView: View {
    let url: URL
    let onRegionsChanged: (Bool) -> Void
    @State private var player: AVPlayer?
    @StateObject private var monitor = VideoSafetyMonitor()

    var body: some View {
        VideoPlayer(player: player)
            .disabled(true)
            .onAppear {
                guard player == nil else { return }
                let newPlayer = AVPlayer(url: url)
                newPlayer.isMuted = true
                player = newPlayer
                if let item = newPlayer.currentItem { monitor.attach(to: item) }
                newPlayer.play()
            }
            .onDisappear { player?.pause() }
            .onReceive(monitor.$regions) { regions in onRegionsChanged(!regions.isEmpty) }
            .onDisappear { monitor.stop() }
    }
}
