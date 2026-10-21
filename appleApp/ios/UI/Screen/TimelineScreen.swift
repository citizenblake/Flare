import SwiftUI
import Combine
import UIKit
@preconcurrency import KotlinSharedUI
import FlareAppleCore
import FlareAppleUI
import SwiftUIBackports

struct TimelineScreen: View {
    let tabItem: UiTimelineTabItem
    let allowGalleryMode: Bool
    let isHomeTimeline: Bool
    let accessoryItems: [UITimelineCollectionViewAccessoryItem]
    @Environment(\.timelineAppearance) private var timelineAppearance
    @Environment(\.appSettings) private var appSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var presenter: KotlinPresenter<TimelineItemPresenterState>
    @State private var isAtTop = true
    @State private var firstVisibleIndex = 0
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
            onFirstVisibleIndexChanged: { firstVisibleIndex = $0 },
            readingPositionSync: readingPositionSync
        )
            .environment(\.timelineAppearance, tabItem.resolveTimelineAppearance(base: timelineAppearance))
        .environment(\.timelineReading, presenter.state.reading)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                if presenter.state.reading?.hasNewContent == true {
                    Button {
                        presenter.state.reading?.showLatest()
                    } label: {
                        Label("home_timeline_view_latest", systemImage: "chevron.up.2")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .backport
                    .glassEffect(.regularInteractive, in: .capsule, fallbackBackground: .regularMaterial)
                    .accessibilityIdentifier("home-new-content")
                    .transition(reduceMotion ? .opacity : .move(edge: .top))
                }
            }
            .animation(
                reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 1),
                value: presenter.state.reading?.hasNewContent == true
            )
            .clipped()
            .padding(.top, 8)
        }
            .refreshable {
                try? await presenter.state.refreshSuspend()
            }
            .onReceive(NotificationCenter.default.publisher(for: .tabDoubleTapped)) { notification in
                guard notification.object as? String == HomeTabsPresenterStateHomeTabs.home.name.lowercased(),
                      isHomeTimeline, isAtTop, !isTabRefreshInFlight,
                      !presenter.state.isRefreshing else { return }
                isTabRefreshInFlight = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    defer { isTabRefreshInFlight = false }
                    try? await presenter.state.refreshSuspend()
                }
            }
            .task(id: "\(isHomeTimeline)-\(isNearTop)-\(scenePhase)-\(appSettings.homeTimelineLoadNewerNearTop)-\(appSettings.rememberHomeTimelinePosition)") {
                try? await loadNewerWhileNearTop()
            }
            .task(id: scenePhase) {
                await loadNewerOnActivation()
            }
    }

    // Within a few posts of the newest one: close enough to keep loading newer posts above.
    private var isNearTop: Bool { firstVisibleIndex < 5 }

    // Background refreshes only run while Home remembers the reading position: that is
    // what makes a refresh insert newer posts above instead of replacing the timeline.
    private var canRefreshInBackground: Bool {
        isHomeTimeline && appSettings.homeTimelineLoadNewerNearTop && appSettings.rememberHomeTimelinePosition
    }

    // Coming back to the app fetches what was posted meanwhile, wherever the reader is.
    private func loadNewerOnActivation() async {
        guard canRefreshInBackground, scenePhase == .active, !isNearTop,
              case .success = onEnum(of: presenter.state.listState) else { return }
        try? await presenter.state.refreshSuspend()
    }

    private func loadNewerWhileNearTop() async throws {
        guard canRefreshInBackground, isNearTop, scenePhase == .active else { return }
        while true {
            if !presenter.state.isRefreshing, case .success = onEnum(of: presenter.state.listState) {
                try? await presenter.state.refreshSuspend()
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
