import SwiftUI
import FlareAppleUI
@preconcurrency import KotlinSharedUI
import FlareAppleCore

struct StatusDetailScreen: View {
    @Environment(\.timelineAppearance.timelineDisplayMode) private var timelineDisplayMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL
    @State private var presenter: KotlinPresenter<StatusContextPresenterState>
    private let statusKey: MicroBlogKey
    private let accountType: AccountType
    private let onReply: () -> Void

    init(accountType: AccountType, statusKey: MicroBlogKey, onReply: @escaping () -> Void = {}) {
        self.statusKey = statusKey
        self.accountType = accountType
        self.onReply = onReply
        self._presenter = .init(wrappedValue: .init(presenter: StatusContextPresenter(accountType: accountType, statusKey: statusKey)))
    }

    var body: some View {
        ZStack {
            UITimelinePagingView(
                data: presenter.state.listState,
                detailStatusKey: statusKey,
                key: presenter.key,
                suppressInitialRefreshIndicator: true,
                columnPolicy: .single
            )
                .frame(maxWidth: 600, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(timelineDisplayMode == .plain ? .clear : .systemGroupedBackground))
        .navigationTitle("status_detail_title")
        .safeAreaInset(edge: .bottom) {
            replyBar
        }
    }

    // A field-shaped button that opens the composer, so replying doesn't need the small
    // reply icon on the post. Signed-out (guest) viewers can't reply, so they get no bar.
    @ViewBuilder
    private var replyBar: some View {
        if accountType is AccountType.Specific {
            Button {
                onReply()
            } label: {
                Label("Post your reply", systemImage: "arrowshape.turn.up.left")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 600)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}
