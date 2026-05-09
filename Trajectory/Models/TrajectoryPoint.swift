import CoreLocation
import Foundation

struct TrajectoryPoint: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let speed: Double
    let timestamp: Date

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        speed: Double,
        timestamp: Date
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.timestamp = timestamp
    }

    init(location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            timestamp: location.timestamp
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: TrajectoryPoint) -> CLLocationDistance {
        let current = CLLocation(latitude: latitude, longitude: longitude)
        let previous = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return current.distance(from: previous)
    }
}

struct FootprintDay: Identifiable, Hashable {
    let id: String
    let date: Date
    let points: [TrajectoryPoint]

    var distanceMeters: Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { partial, pair in
            partial + pair.1.distance(to: pair.0)
        }
    }

    var duration: TimeInterval {
        guard let first = points.first?.timestamp, let last = points.last?.timestamp else {
            return 0
        }
        return last.timeIntervalSince(first)
    }

    var startTime: Date? {
        points.first?.timestamp
    }

    var endTime: Date? {
        points.last?.timestamp
    }

    var coordinates: [CLLocationCoordinate2D] {
        points.map(\.coordinate)
    }
}

extension Calendar {
    func trajectoryDayID(for date: Date) -> String {
        let components = dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum TrajectoryFormatter {
    static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func speed(_ metersPerSecond: Double) -> String {
        guard metersPerSecond >= 0 else { return "--" }
        return String(format: "%.1f km/h", metersPerSecond * 3.6)
    }

    static func coordinate(_ point: TrajectoryPoint?) -> String {
        guard let point else { return "等待定位" }
        return String(format: "%.5f, %.5f", point.latitude, point.longitude)
    }
}
