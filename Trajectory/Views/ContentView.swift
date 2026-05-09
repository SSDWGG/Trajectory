import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissionAlert: TrackingPermissionIssue?
    @State private var dismissedPermissionIssueID: TrackingPermissionIssue.ID?

    var body: some View {
        TabView {
            NavigationStack {
                FootprintView()
            }
            .tabItem {
                Label("足迹", systemImage: "map")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("日历", systemImage: "calendar")
            }

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("统计", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .onAppear {
            presentPermissionAlertIfNeeded(force: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            presentPermissionAlertIfNeeded(force: true)
        }
        .onChange(of: tracker.authorizationStatus) {
            presentPermissionAlertIfNeeded()
        }
        .alert(item: $permissionAlert) { issue in
            Alert(
                title: Text(issue.title),
                message: Text(issue.message),
                primaryButton: .default(Text(issue.actionTitle)) {
                    handlePermissionAction(for: issue)
                },
                secondaryButton: .cancel(Text("稍后")) {
                    dismissedPermissionIssueID = issue.id
                }
            )
        }
    }

    private func presentPermissionAlertIfNeeded(force: Bool = false) {
        guard let issue = tracker.permissionIssue else {
            permissionAlert = nil
            dismissedPermissionIssueID = nil
            return
        }

        guard force || dismissedPermissionIssueID != issue.id else { return }
        permissionAlert = issue
    }

    private func handlePermissionAction(for issue: TrackingPermissionIssue) {
        dismissedPermissionIssueID = nil

        if issue.shouldOpenSystemSettings {
            openSystemSettings()
        } else {
            tracker.requestPermission()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
