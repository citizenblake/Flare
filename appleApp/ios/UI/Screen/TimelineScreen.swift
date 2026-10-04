import SwiftUI
import Combine
import UIKit
@preconcurrency import KotlinSharedUI
import FlareAppleCore
import FlareAppleUI

struct TimelineScreen: View {
    let tabItem: UiTimelineTabItem
    let allowGalleryMode: Bool
    let isHomeTimeline: Bool
    let accessoryItems: [UITimelineCollectionViewAccessoryItem]
    @Environment(\.timelineAppearance) private var timelineAppearance
    @Environment(\.appSettings) private var appSettings
    @Environment(\.scenePhase) private var scenePhase
    @State var presenter: KotlinPresenter<TimelineItemPresenterState>
    @State private var isAtTop = true
    @State private var isNearTop = true
    @State private var readingPositionSync: ReadingPositionSync?
    @State private var isTabRefreshInFlight = false
    init(
        tabItem: UiTimelineTabItem,
        allowGalleryMode: Bool = true,
        isHomeTimeline: Bool = false,
        accessoryItems: [UITimelineCollectionViewAccessoryItem] = []
    ) {
        self.tabItem = tabItem
        self.allowGalleryMode = allowGalleryMode
        self.isHomeTimeline = isHomeTimeline
        self.accessoryItems = accessoryItems
        self._readingPositionSync = .init(initialValue: isHomeTimeline ? ReadingPositionSync(timelineKey: tabItem.id) : nil)
        self._presenter = .init(
            wrappedValue: .init(
                presenter: TimelineItemPresenter(
                    timelineTabItem: tabItem,
                    isHomeTimeline: isHomeTimeline
                )
            )
        )
    }
    var body: some View {
        UITimelinePagingView(
            data: presenter.state.listState,
            detailStatusKey: nil,
            key: "timeline:\(tabItem.id):\(tabItem.loaderKey)",
            allowGalleryMode: allowGalleryMode,
            accessoryItems: accessoryItems,
            onIsAtTopChanged: { isAtTop = $0 },
            onIsNearTopChanged: { isNearTop = $0 },
            readingPositionSync: readingPositionSync
        )
            .environment(\.timelineAppearance, tabItem.resolveTimelineAppearance(base: timelineAppearance))
            .refreshable {
                await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .tabDoubleTapped)) { notification in
                guard notification.object as? String == HomeTabsPresenterStateHomeTabs.home.name.lowercased(),
                      isHomeTimeline, isAtTop, !isTabRefreshInFlight,
                      !presenter.state.isRefreshing else { return }
                isTabRefreshInFlight = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    defer { isTabRefreshInFlight = false }
                    await refresh()
                }
            }
            .task(id: "\(isHomeTimeline)-\(isNearTop)-\(scenePhase)-\(appSettings.homeTimelineLoadNewerNearTop)") {
                try? await loadNewerWhileNearTop()
            }
            .task(id: scenePhase) {
                await loadNewerOnActivation()
            }
    }

    // Coming back to the app fetches what was posted meanwhile, wherever the reader is.
    private func loadNewerOnActivation() async {
        guard isHomeTimeline, appSettings.homeTimelineLoadNewerNearTop, scenePhase == .active, !isNearTop,
              case .success = onEnum(of: presenter.state.listState) else { return }
        _ = try? await presenter.state.loadNewerSuspend(refreshIfUncached: false)
    }

    // Home inserts newer posts above the loaded ones so the reader keeps their place;
    // a full refresh would replace the timeline. Other timelines keep the full refresh.
    private func refresh() async {
        if isHomeTimeline, case .success = onEnum(of: presenter.state.listState) {
            _ = try? await presenter.state.loadNewerSuspend(refreshIfUncached: true)
        } else {
            try? await presenter.state.refreshSuspend()
        }
    }

    private func loadNewerWhileNearTop() async throws {
        guard isHomeTimeline, isNearTop, appSettings.homeTimelineLoadNewerNearTop, scenePhase == .active else { return }
        while true {
            // Never a full refresh here: it would replace the timeline the reader is in.
            if !presenter.state.isRefreshing, case .success = onEnum(of: presenter.state.listState) {
                _ = try? await presenter.state.loadNewerSuspend(refreshIfUncached: false)
            }
            // Servers don't push new posts, so re-check while the reader stays near the top.
            // ponytail: Mastodon streaming could replace the poll for that side.
            try await Task.sleep(for: .seconds(15))
        }
    }
}

struct ListTimelineScreen:  View {
    let tabItem: UiTimelineTabItem
    var body: some View {
        TimelineScreen(tabItem: tabItem)
    }
}
