import Combine
import CoreLocation
import Foundation

enum TrackingAccuracy: String, CaseIterable, Identifiable {
    case powerSaving
    case balanced
    case best
    case navigation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .powerSaving:
            return "省电"
        case .balanced:
            return "均衡"
        case .best:
            return "精确"
        case .navigation:
            return "导航级"
        }
    }

    var coreLocationAccuracy: CLLocationAccuracy {
        switch self {
        case .powerSaving:
            return kCLLocationAccuracyHundredMeters
        case .balanced:
            return kCLLocationAccuracyNearestTenMeters
        case .best:
            return kCLLocationAccuracyBest
        case .navigation:
            return kCLLocationAccuracyBestForNavigation
        }
    }

    var activityType: CLActivityType {
        switch self {
        case .powerSaving:
            return .other
        case .balanced, .best:
            return .fitness
        case .navigation:
            return .automotiveNavigation
        }
    }

    var allowsAutomaticPause: Bool {
        switch self {
        case .powerSaving, .balanced:
            return true
        case .best, .navigation:
            return false
        }
    }

    var detail: String {
        switch self {
        case .powerSaving:
            return "低频记录，适合日常后台留痕"
        case .balanced:
            return "常规记录，兼顾轨迹和耗电"
        case .best:
            return "更密集定位，适合步行和旅行"
        case .navigation:
            return "最高精度，适合短时运动"
        }
    }
}

enum TrackingPermissionIssue: String, Equatable, Identifiable {
    case locationServicesDisabled
    case needsAlwaysAuthorization
    case authorizationDenied
    case authorizationRestricted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .locationServicesDisabled:
            return "需要开启定位服务"
        case .needsAlwaysAuthorization:
            return "需要始终允许定位"
        case .authorizationDenied:
            return "定位权限已关闭"
        case .authorizationRestricted:
            return "定位权限受限制"
        }
    }

    var message: String {
        switch self {
        case .locationServicesDisabled:
            return "Trajectory 需要系统定位服务来自动记录运动轨迹。请在系统设置中开启定位服务。"
        case .needsAlwaysAuthorization:
            return "Trajectory 打开后会自动记录轨迹。为了在后台也能持续记录，请将定位权限设为“始终允许”。"
        case .authorizationDenied:
            return "Trajectory 无法访问定位，因此不能记录轨迹。请在系统设置中允许定位权限。"
        case .authorizationRestricted:
            return "当前设备限制了定位权限，Trajectory 暂时不能记录轨迹。"
        }
    }

    var actionTitle: String {
        switch self {
        case .needsAlwaysAuthorization:
            return "继续授权"
        case .locationServicesDisabled, .authorizationDenied, .authorizationRestricted:
            return "打开设置"
        }
    }

    var shouldOpenSystemSettings: Bool {
        switch self {
        case .needsAlwaysAuthorization:
            return false
        case .locationServicesDisabled, .authorizationDenied, .authorizationRestricted:
            return true
        }
    }
}

@MainActor
final class LocationTracker: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization
    @Published private(set) var isTracking = false
    @Published private(set) var isContinuousTrackingEnabled: Bool
    @Published private(set) var isPausedBySystem = false
    @Published private(set) var lastRecordedPoint: TrajectoryPoint?
    @Published private(set) var lastMessage: String?
    @Published private(set) var trackingStartedAt: Date?

    @Published var distanceFilter: Double {
        didSet {
            UserDefaults.standard.set(distanceFilter, forKey: Self.distanceFilterKey)
            manager.distanceFilter = distanceFilter
        }
    }

    @Published var accuracy: TrackingAccuracy {
        didSet {
            UserDefaults.standard.set(accuracy.rawValue, forKey: Self.accuracyKey)
            applyConfiguration()
        }
    }

    @Published var showsBackgroundIndicator: Bool {
        didSet {
            UserDefaults.standard.set(showsBackgroundIndicator, forKey: Self.backgroundIndicatorKey)
            manager.showsBackgroundLocationIndicator = showsBackgroundIndicator
        }
    }

    private static let distanceFilterKey = "tracking.distanceFilter"
    private static let accuracyKey = "tracking.accuracy"
    private static let backgroundIndicatorKey = "tracking.showsBackgroundIndicator"
    private static let continuousTrackingKey = "tracking.continuous.enabled"

    private let manager: CLLocationManager
    private let store: TrackStore
    private var startRequested = false

    init(store: TrackStore) {
        let manager = CLLocationManager()
        self.manager = manager
        self.store = store
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        isContinuousTrackingEnabled = UserDefaults.standard.bool(forKey: Self.continuousTrackingKey)

        let savedDistance = UserDefaults.standard.object(forKey: Self.distanceFilterKey) as? Double
        distanceFilter = savedDistance ?? 30

        let savedAccuracy = UserDefaults.standard.string(forKey: Self.accuracyKey)
        accuracy = savedAccuracy.flatMap(TrackingAccuracy.init(rawValue:)) ?? .balanced

        let savedIndicator = UserDefaults.standard.object(forKey: Self.backgroundIndicatorKey) as? Bool
        showsBackgroundIndicator = savedIndicator ?? true

        super.init()

        manager.delegate = self
        applyConfiguration()
        resumeTrackingIfNeeded()
    }

    var canTrackInBackground: Bool {
        authorizationStatus == .authorizedAlways
    }

    var authorizationText: String {
        switch authorizationStatus {
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用期间允许"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限制"
        case .notDetermined:
            return "未授权"
        @unknown default:
            return "未知"
        }
    }

    var accuracyAuthorizationText: String {
        switch accuracyAuthorization {
        case .fullAccuracy:
            return "精确"
        case .reducedAccuracy:
            return "大致"
        @unknown default:
            return "未知"
        }
    }

    var permissionIssue: TrackingPermissionIssue? {
        guard CLLocationManager.locationServicesEnabled() else {
            return .locationServicesDisabled
        }

        switch authorizationStatus {
        case .authorizedAlways, .notDetermined:
            return nil
        case .authorizedWhenInUse:
            return .needsAlwaysAuthorization
        case .denied:
            return .authorizationDenied
        case .restricted:
            return .authorizationRestricted
        @unknown default:
            return .authorizationRestricted
        }
    }

    func beginAutomaticTracking() {
        startTracking()
    }

    func requestPermission() {
        guard CLLocationManager.locationServicesEnabled() else {
            lastMessage = "系统定位服务未开启"
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            lastMessage = "后台定位权限已开启"
        case .denied, .restricted:
            lastMessage = "请在系统设置中允许 Trajectory 使用定位"
        @unknown default:
            lastMessage = "当前定位授权状态暂不支持"
        }
    }

    func startTracking() {
        setContinuousTrackingEnabled(true)
        startRequested = true

        guard CLLocationManager.locationServicesEnabled() else {
            lastMessage = "系统定位服务未开启"
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            startLocationUpdates()
        case .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            lastMessage = "定位权限未开启，无法记录足迹"
        @unknown default:
            lastMessage = "当前定位授权状态暂不支持"
        }
    }

    func stopTracking() {
        startRequested = false
        isTracking = false
        setContinuousTrackingEnabled(false)
        isPausedBySystem = false
        trackingStartedAt = nil
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.allowsBackgroundLocationUpdates = false
        lastMessage = "足迹记录已停止"
    }

    func resumeTrackingIfNeeded() {
        guard isContinuousTrackingEnabled, !isTracking else { return }

        startRequested = true

        guard CLLocationManager.locationServicesEnabled() else {
            lastMessage = "系统定位服务未开启"
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationUpdates()
        case .notDetermined:
            lastMessage = "开启定位权限后会继续记录足迹"
        case .denied, .restricted:
            lastMessage = "定位权限未开启，无法恢复后台记录"
        @unknown default:
            lastMessage = "当前定位授权状态暂不支持"
        }
    }

    func handleAppBecameActive() {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        resumeTrackingIfNeeded()
    }

    func handleAppEnteredBackground() {
        guard isTracking else { return }

        if canTrackInBackground {
            lastMessage = "已进入后台，将继续记录足迹"
        } else {
            lastMessage = "后台记录需要“始终允许”定位权限"
        }
    }

    private func startLocationUpdates() {
        applyConfiguration()
        isTracking = true
        isPausedBySystem = false
        trackingStartedAt = trackingStartedAt ?? Date()
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()

        if authorizationStatus == .authorizedAlways {
            lastMessage = "正在后台记录足迹"
        } else {
            lastMessage = "正在记录足迹，后台运行需要始终允许权限"
        }
    }

    private func applyConfiguration() {
        manager.desiredAccuracy = accuracy.coreLocationAccuracy
        manager.distanceFilter = distanceFilter
        manager.activityType = accuracy.activityType
        manager.pausesLocationUpdatesAutomatically = accuracy.allowsAutomaticPause
        manager.allowsBackgroundLocationUpdates = isContinuousTrackingEnabled
        manager.showsBackgroundLocationIndicator = showsBackgroundIndicator
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        accuracyAuthorization = manager.accuracyAuthorization

        if status == .authorizedWhenInUse, startRequested {
            manager.requestAlwaysAuthorization()
            startLocationUpdates()
        } else if status == .authorizedAlways, startRequested {
            startLocationUpdates()
        } else if status == .denied || status == .restricted {
            isTracking = false
            manager.stopUpdatingLocation()
            manager.stopMonitoringSignificantLocationChanges()
            lastMessage = "定位权限未开启，无法记录足迹"
        }
    }

    private func record(_ point: TrajectoryPoint) {
        lastRecordedPoint = point
        store.append(point)
    }

    private func setContinuousTrackingEnabled(_ enabled: Bool) {
        isContinuousTrackingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.continuousTrackingKey)
        manager.allowsBackgroundLocationUpdates = enabled
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let point = TrajectoryPoint(location: latest)
        Task { @MainActor [weak self] in
            self?.record(point)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.lastMessage = "定位失败：\(message)"
        }
    }

    nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.isPausedBySystem = true
        }
    }

    nonisolated func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.isPausedBySystem = false
        }
    }
}
