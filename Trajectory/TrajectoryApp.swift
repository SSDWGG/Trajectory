import SwiftUI

@main
@MainActor
struct TrajectoryApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: TrackStore
    @StateObject private var tracker: LocationTracker

    init() {
        let store = TrackStore()
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: LocationTracker(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(tracker)
                .onAppear {
                    tracker.beginAutomaticTracking()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        tracker.handleAppBecameActive()
                    case .background:
                        tracker.handleAppEnteredBackground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
