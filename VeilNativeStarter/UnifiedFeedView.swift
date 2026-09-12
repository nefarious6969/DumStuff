import SwiftUI

struct UnifiedFeedView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var settings: SafetySettings

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(store.visibleItems) { item in
                        VStack(alignment: .leading, spacing: 11) {
                            HStack {
                                Text(item.source.rawValue).font(.subheadline.weight(.semibold))
                                Text("· \(item.author)").foregroundStyle(.secondary)
                                Spacer()
                                Button(item.isSaved ? "Saved" : "Save") { store.toggleSaved(item) }.font(.caption)
                            }
                            ProtectedMediaView(item: item)
                            Text(item.title).font(.title3.weight(.semibold))
                            Text(item.body).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 28)
            }
            .navigationTitle("For you")
            .task { await store.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(FeedSource.allCases) { source in
                            Button(source.rawValue) { store.selectedSource = source }
                        }
                    } label: { Label(store.selectedSource.rawValue, systemImage: "line.3.horizontal.decrease.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settings.isEnabled.toggle() } label: { Image(systemName: settings.isEnabled ? "eye.slash" : "eye") }
                }
            }
            .refreshable { await store.refresh() }
        }
    }
}
