import SwiftUI
import KotlinSharedUI
import LazyPager
import Combine
import FlareAppleCore
import FlareAppleUI

struct Router<Root: View>: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appSettings) private var appSettings
    @ViewBuilder let root: (@escaping (Route) -> Void) -> Root
    @State private var backStack: [Route] = []
    @State private var sheet: Route? = nil
    @State private var cover: Route? = nil
    @State private var alertRoute: Route? = nil
    @State private var deepLinkPresenter: KotlinPresenter<DeepLinkPresenterState>
    @State private var deepLinkHandler: DeepLinkHandler
    
    init(@ViewBuilder root: @escaping (@escaping (Route) -> Void) -> Root) {
        self.root = root
        let handler = DeepLinkHandler()
        self._deepLinkPresenter = .init(wrappedValue: .init(presenter: DeepLinkPresenter(onRoute: { [weak handler] deeplinkRoute in
            if let route = Route.fromDeepLinkRoute(deeplinkRoute: deeplinkRoute){
                handler?.onRoute?(route)
            }
        }, onLink: { [weak handler] link in
            handler?.onLink?(link)
        })))
        self.deepLinkHandler = handler
    }
    
    private static var primaryColumnWidth: CGFloat { 400 }

    private var usesSideBySide: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular && appSettings.sideBySideOnWideScreens
    }

    // On a wide screen the list stays on the left and whatever it opens (a post, a profile,
    // a settings page) shows on the right, instead of replacing the list.
    @ViewBuilder
    private var navigation: some View {
        if usesSideBySide {
            HStack(spacing: 0) {
                NavigationStack {
                    root({ route in
                        navigate(route: route)
                    })
                }
                // The narrow column lays out like a phone.
                .environment(\.horizontalSizeClass, .compact)
                .frame(width: Self.primaryColumnWidth)
                Divider()
                    .ignoresSafeArea()
                NavigationStack(path: $backStack) {
                    ContentUnavailableView(
                        "Nothing open",
                        systemImage: "rectangle.righthalf.inset.filled",
                        description: Text("Posts, profiles and pages you open appear here.")
                    )
                    .navigationDestination(for: Route.self) { route in
                        route.view(
                            onNavigate: { route in navigate(route: route) },
                            goBack: { backStack.removeLast() }
                        )
                    }
                }
            }
        } else {
            NavigationStack(path: $backStack) {
                root({ route in
                    navigate(route: route)
                })
                .navigationDestination(for: Route.self) { route in
                    route.view(
                        onNavigate: { route in navigate(route: route) },
                        goBack: { backStack.removeLast() }
                    )
                }
            }
        }
    }

    var body: some View {
        navigation
        .environment(\.timelineMediaActionHandler, IOSTimelineMediaActions.handler)
        .sheet(item: $sheet) { route in
            if #available(iOS 18.0, *) {
                NavigationStack {
                    route.view(
                        onNavigate: { route in navigate(route: route) },
                        goBack: { backStack.removeLast() }
                    )
                }
            } else {
                NavigationStack {
                    route.view(
                        onNavigate: { route in navigate(route: route) },
                        goBack: { backStack.removeLast() }
                    )
                    .navigationDestination(for: Route.self) { destination in
                        destination.view(
                            onNavigate: { route in navigate(route: route) },
                            goBack: {}
                        )
                    }
                }
            }
        }
        .fullScreenCover(item: $cover) { route in
            NavigationStack {
                route.view(
                    onNavigate: { route in navigate(route: route) },
                    goBack: { backStack.removeLast() }
                )
            }
            .background(ClearFullScreenBackground())
            .colorScheme(.dark)
        }
        .alert(alertRoute?.alertTitle ?? "", isPresented: Binding(get: { alertRoute != nil }, set: { if !$0 { alertRoute = nil } })) {
            alertRoute?.alertActions()
        } message: {
            alertRoute?.alertMessage()
        }
        .environment(\.openURL, OpenURLAction { url in
            deepLinkPresenter.state.handle(url: url.absoluteString)
            return .handled
        })
        .onOpenURL { url in
            let targetURL = url.openInFlareTargetURL ?? url
            deepLinkPresenter.state.handle(url: targetURL.absoluteString)
        }
        .onAppear {
            deepLinkHandler.onRoute = { route in
                navigate(route: route)
            }
            deepLinkHandler.onLink = { link in
                if let url = URL(string: link) {
                    openURL(url)
                }
            }
        }
    }

    func navigate(route: Route) {
        if route.alertTitle != nil {
            alertRoute = route
        } else if isSheetRoute(route: route) {
            sheet = route
        } else if isFullScreenCover(route: route) {
            cover = route
        } else if backStack.last != route {
            backStack.append(route)
            sheet = nil
            cover = nil
        }
    }
    
    func isSheetRoute(route: Route) -> Bool {
        switch route {
        case .deepLinkAccountPicker,
                .composeNew,
                .composeCrossPost,
                .composeDraft,
                .composeQuote,
                .composeReply,
                .composeVVOReplyComment,
                .relogin,
                .tabSettings,
                .statusBlueskyReport,
                .statusMisskeyReport,
                .editUserList,
                .statusShareSheet,
                .secondaryMenu,
                .statusInsight,
                .profileInsight,
                .statusAddReaction:
            return true
        default:
            return false
        }
    }
    
    func isFullScreenCover(route: Route) -> Bool {
        switch route {
        case .mediaStatusMedia, .mediaImage, .mediaRaw:
            return true
        default:
            return false
        }
    }
}

final class DeepLinkHandler {
    var onRoute: ((Route) -> Void)?
    var onLink: ((String) -> Void)?
}

private extension URL {
    var openInFlareTargetURL: URL? {
        guard scheme?.lowercased() == "flare",
              host?.lowercased() == "open",
              let targetValue = URLComponents(
                  url: self,
                  resolvingAgainstBaseURL: false
              )?.queryItems?.first(where: { $0.name == "url" })?.value,
              let targetURL = URL(string: targetValue),
              let targetScheme = targetURL.scheme?.lowercased(),
              targetScheme == "https" || targetScheme == "http"
        else {
            return nil
        }
        return targetURL
    }
}
