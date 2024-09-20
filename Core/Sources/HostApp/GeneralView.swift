import Client
import ComposableArchitecture
import KeyboardShortcuts
import LaunchAgentManager
import Preferences
import SharedUIComponents
import SwiftUI

struct GeneralView: View {
    let store: StoreOf<General>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppInfoView(store: store)
                SettingsDivider()
                GitHubCopilotView()
                SettingsDivider()
                ExtensionServiceView(store: store)
                SettingsDivider()
                LaunchAgentView()
                SettingsDivider()
                GeneralSettingsView()
            }
        }
        .onAppear {
            store.send(.appear)
        }
    }
}

struct AppInfoView: View {
    @State var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    @Environment(\.updateChecker) var updateChecker
    let store: StoreOf<General>

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text(
                    Bundle.main
                        .object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
                        ?? "GitHub Copilot for Xcode"
                )
                .font(.title)
                Text(appVersion ?? "")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    updateChecker.checkForUpdates()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right.circle.fill")
                        Text("Check for Updates")
                    }
                }
            }
        }.padding()
    }
}

struct ExtensionServiceView: View {
    @Perception.Bindable var store: StoreOf<General>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading) {
                Text("Extension Service Version: \(store.xpcServiceVersion ?? "Loading..")")

                let grantedStatus: String = {
                    guard let granted = store.isAccessibilityPermissionGranted
                    else { return "Loading.." }
                    return granted ? "Granted" : "Not Granted"
                }()
                Text("Accessibility Permission: \(grantedStatus)")

                HStack {
                    Button(action: { store.send(.reloadStatus) }) {
                        Text("Refresh")
                    }.disabled(store.isReloading)

                    Button(action: {
                        Task {
                            let workspace = NSWorkspace.shared
                            let url = Bundle.main.bundleURL
                                .appendingPathComponent("Contents")
                                .appendingPathComponent("Applications")
                                .appendingPathComponent("GitHub Copilot for Xcode Extension.app")
                            workspace.activateFileViewerSelecting([url])
                        }
                    }) {
                        Text("Reveal Extension Service in Finder")
                    }

                    Button(action: {
                        let url = URL(
                            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        )!
                        NSWorkspace.shared.open(url)
                    }) {
                        Text("Accessibility Settings")
                    }

                    Button(action: {
                        let url = URL(
                            string: "x-apple.systempreferences:com.apple.ExtensionsPreferences"
                        )!
                        NSWorkspace.shared.open(url)
                    }) {
                        Text("Extensions Settings")
                    }
                }
            }
        }
        .padding()
    }
}

struct LaunchAgentView: View {
    @Environment(\.toast) var toast
    @State var isDidRemoveLaunchAgentAlertPresented = false
    @State var isDidSetupLaunchAgentAlertPresented = false
    @State var isDidRestartLaunchAgentAlertPresented = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    Task {
                        do {
                            try await LaunchAgentManager().setupLaunchAgent()
                            isDidSetupLaunchAgentAlertPresented = true
                        } catch {
                            toast(error.localizedDescription, .error)
                        }
                    }
                }) {
                    Text("Set Up Launch Agent")
                }
                .alert(isPresented: $isDidSetupLaunchAgentAlertPresented) {
                    .init(
                        title: Text("Finished Launch Agent Setup"),
                        message: Text(
                            "Please refresh the Copilot status. (The first refresh may fail)"
                        ),
                        dismissButton: .default(Text("OK"))
                    )
                }

                Button(action: {
                    Task {
                        do {
                            try await LaunchAgentManager().removeLaunchAgent()
                            isDidRemoveLaunchAgentAlertPresented = true
                        } catch {
                            toast(error.localizedDescription, .error)
                        }
                    }
                }) {
                    Text("Remove Launch Agent")
                }
                .alert(isPresented: $isDidRemoveLaunchAgentAlertPresented) {
                    .init(
                        title: Text("Launch Agent Removed"),
                        dismissButton: .default(Text("OK"))
                    )
                }

                Button(action: {
                    Task {
                        do {
                            try await LaunchAgentManager().reloadLaunchAgent()
                            isDidRestartLaunchAgentAlertPresented = true
                        } catch {
                            toast(error.localizedDescription, .error)
                        }
                    }
                }) {
                    Text("Reload Launch Agent")
                }.alert(isPresented: $isDidRestartLaunchAgentAlertPresented) {
                    .init(
                        title: Text("Launch Agent Reloaded"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .padding()
    }
}

struct GeneralSettingsView: View {
    class Settings: ObservableObject {
        @AppStorage(\.quitXPCServiceOnXcodeAndAppQuit)
        var quitXPCServiceOnXcodeAndAppQuit
        @AppStorage(\.suggestionWidgetPositionMode)
        var suggestionWidgetPositionMode
        @AppStorage(\.widgetColorScheme)
        var widgetColorScheme
        @AppStorage(\.preferWidgetToStayInsideEditorWhenWidthGreaterThan)
        var preferWidgetToStayInsideEditorWhenWidthGreaterThan
        @AppStorage(\.showHideWidgetShortcutGlobally)
        var showHideWidgetShortcutGlobally
        @AppStorage(\.installPrereleases)
        var installPrereleases
    }

    @StateObject var settings = Settings()
    @Environment(\.updateChecker) var updateChecker
    @State var automaticallyCheckForUpdate: Bool?

    var body: some View {
        Form {
            Toggle(isOn: $settings.quitXPCServiceOnXcodeAndAppQuit) {
                Text("Quit service when Xcode and host app are terminated")
            }

            Toggle(isOn: .init(
                get: { automaticallyCheckForUpdate ?? updateChecker.automaticallyChecksForUpdates },
                set: {
                    updateChecker.automaticallyChecksForUpdates = $0
                    automaticallyCheckForUpdate = $0
                }
            )) {
                Text("Automatically Check for Updates")
            }

            Toggle(isOn: $settings.installPrereleases) {
                Text("Install pre-releases")
            }
        }.padding()
    }
}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView(store: .init(initialState: .init(), reducer: { General() }))
            .frame(height: 800)
    }
}

