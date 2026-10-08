import SwiftUI
import FlareAppleUI
import KotlinSharedUI
import FlareAppleCore

struct SettingsScreen: View {
    var body: some View {
        List {
            NavigationLink(value: Route.accountManagement) {
                Label {
                    Text("account_management_title")
                    Text("account_management_description")
                } icon: {
                    Image(fontAwesome: .circleUser)
                }
            }

            Section {
                NavigationLink(value: Route.appearanceTheme) {
                    Label {
                        Text("appearance_theme")
                        Text("appearance_theme_group_subtitle")
                    } icon: {
                        Image(fontAwesome: .palette)
                    }
                }
                NavigationLink(value: Route.appearanceLayout) {
                    Label {
                        Text("appearance_layout_group_title")
                        Text("appearance_layout_group_subtitle")
                    } icon: {
                        Image(fontAwesome: .tableList)
                    }
                }
                NavigationLink(value: Route.appearanceDisplay) {
                    Label {
                        Text("appearance_display_group_title")
                        Text("appearance_display_group_subtitle")
                    } icon: {
                        Image(fontAwesome: .newspaper)
                    }
                }
                NavigationLink(value: Route.appearanceMedia) {
                    Label {
                        Text("appearance_media_group_title")
                        Text("appearance_media_group_subtitle")
                    } icon: {
                        Image(fontAwesome: .photoFilm)
                    }
                }
                NavigationLink(value: Route.appIconSettings) {
                    Label {
                        Text("App Icon")
                        Text("Choose the icon shown on your Home Screen")
                    } icon: {
                        Image(fontAwesome: .palette)
                    }
                }
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label {
                            Text("system_settings_title")
                            Text("system_settings_description")
                        } icon: {
                            Image(fontAwesome: .gear)
                        }
                    }
                }
                
//                StateView(state: presenter.state.user) { _ in
//                    NavigationLink(value: Route.moreMenuCustomize) {
//                        Label {
//                            Text("more_panel_customize")
//                        } icon: {
//                            Image(fontAwesome: .tableList)
//                        }
//                    }
//                }
            }

            Section {
                NavigationLink(value: Route.behavior) {
                    Label {
                        Text("settings_behavior_title")
                        Text("settings_behavior_description")
                    } icon: {
                        Image(fontAwesome: .sliders)
                    }
                }
            }

            Section {
                NavigationLink(value: Route.localFilter) {
                    Label {
                        Text("local_filter_title")
                        Text("local_filter_description")
                    } icon: {
                        Image(fontAwesome: .filter)
                    }
                }
                NavigationLink(value: Route.storage) {
                    Label {
                        Text("storage_title")
                        Text("storage_description")
                    } icon: {
                        Image(fontAwesome: .database)
                    }
                }
            }

            Section {
                NavigationLink(value: Route.aiConfig) {
                    Label {
                        Text("AI")
                        Text("ai_config_description")
                    } icon: {
                        Image(fontAwesome: .robot)
                    }

                }
                NavigationLink(value: Route.translationConfig) {
                    Label {
                        Text("settings_translation_title")
                        Text("settings_translation_description")
                    } icon: {
                        Image(fontAwesome: .language)
                    }
                }
            }

            Section {
                NavigationLink(value: Route.about) {
                    Label {
                        Text("about_title")
                        Text("about_description")
                    } icon: {
                        Image(fontAwesome: .circleInfo)
                    }
                }
            }
        }
        .navigationTitle("settings_title")
    }
}

/// The timeline reading options this fork adds, in one place.
struct TimelineReadingSettingsSection: View {
    @State private var presenter = KotlinPresenter(presenter: SettingsPresenter())
    @Environment(\.appSettings) private var appSettings

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                appSettings.homeTimelineLoadNewerNearTop
            }, set: { newValue in
                presenter.state.updateHomeTimelineLoadNewerNearTop(value: newValue)
            })) {
                Text("Load newer posts near the top")
                Text("While you're within 5 posts of the top, Home adds newer posts above without moving your place.")
            }
            Toggle(isOn: Binding(get: {
                appSettings.tintPostsByNetwork
            }, set: { newValue in
                presenter.state.updateTintPostsByNetwork(value: newValue)
            })) {
                Text("Tint posts by network")
                Text("Bluesky posts get a pale blue background, Mastodon posts a pale purple one.")
            }
            if UIDevice.current.userInterfaceIdiom == .pad {
                Toggle(isOn: Binding(get: {
                    appSettings.sideBySideOnWideScreens
                }, set: { newValue in
                    presenter.state.updateSideBySideOnWideScreens(value: newValue)
                })) {
                    Text("Side by side")
                    Text("Keep the list on the left and open posts and profiles on the right.")
                }
                Toggle(isOn: Binding(get: {
                    appSettings.timelineMultipleColumns
                }, set: { newValue in
                    presenter.state.updateTimelineMultipleColumns(value: newValue)
                })) {
                    Text("Multiple columns")
                    Text("Show timelines in several columns when there is room.")
                }
            }
            NavigationLink(value: Route.tabSettings) {
                Label {
                    Text("Home tabs and merge order")
                    Text("Choose which timelines Home shows and how the Mixed tab orders them.")
                } icon: {
                    EmptyView()
                }
            }
        } header: {
            Text("Timeline")
        }
    }
}

struct BehaviorSettingsScreen: View {
    var body: some View {
        List {
            TimelineReadingSettingsSection()
            BehaviorSettingsSection {
                NavigationLink(value: Route.linkOpenDefaults) {
                    Label {
                        Text("settings_link_open_defaults_title")
                        Text("settings_link_open_defaults_description")
                    } icon: {
                        EmptyView()
                    }
                }
            }
        }
        .navigationTitle("settings_behavior_title")
    }
}

struct LinkOpenDefaultsSettingsScreen: View {
    var body: some View {
        List {
            LinkOpenDefaultsSettingsSection()
        }
        .navigationTitle("settings_link_open_defaults_title")
    }
}
