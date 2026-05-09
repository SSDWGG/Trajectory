import Combine
import CoreLocation
import Foundation

@MainActor
final class TrackStore: ObservableObject {
    @Published private(set) var points: [TrajectoryPoint]
    @Published var selectedDayID: String?
    @Published var lastStorageError: String?

    private let fileURL: URL
    private let calendar = Calendar.current
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let stationaryDistanceThreshold: CLLocationDistance = 10

    init(fileURL: URL? = nil) {
        let resolvedURL = fileURL ?? Self.defaultStoreURL()
        self.fileURL = resolvedURL

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        points = Self.loadPoints(from: resolvedURL, decoder: decoder)
        selectedDayID = points.last.map { calendar.trajectoryDayID(for: $0.timestamp) }
    }

    var days: [FootprintDay] {
        Dictionary(grouping: points) { point in
            calendar.trajectoryDayID(for: point.timestamp)
        }
        .map { id, points in
            let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
            let date = sortedPoints.first?.timestamp ?? Date()
            return FootprintDay(id: id, date: calendar.startOfDay(for: date), points: sortedPoints)
        }
        .sorted { $0.date > $1.date }
    }

    var selectedDay: FootprintDay? {
        if let selectedDayID, let selected = days.first(where: { $0.id == selectedDayID }) {
            return selected
        }
        return days.first
    }

    var totalDistanceMeters: Double {
        days.reduce(0) { $0 + $1.distanceMeters }
    }

    var totalDuration: TimeInterval {
        days.reduce(0) { $0 + $1.duration }
    }

    var longestDay: FootprintDay? {
        days.max { $0.distanceMeters < $1.distanceMeters }
    }

    var firstRecordedAt: Date? {
        points.first?.timestamp
    }

    var lastRecordedAt: Date? {
        points.last?.timestamp
    }

    var thisMonthDistanceMeters: Double {
        let now = Date()
        return days.reduce(0) { partial, day in
            calendar.isDate(day.date, equalTo: now, toGranularity: .month) ? partial + day.distanceMeters : partial
        }
    }

    var averageDistancePerDay: Double {
        guard !days.isEmpty else { return 0 }
        return totalDistanceMeters / Double(days.count)
    }

    var lastPoint: TrajectoryPoint? {
        points.last
    }

    func select(_ day: FootprintDay) {
        selectedDayID = day.id
    }

    func append(_ point: TrajectoryPoint) {
        guard shouldAccept(point) else { return }
        points.append(point)
        selectedDayID = calendar.trajectoryDayID(for: point.timestamp)
        persist()
    }

    func delete(_ day: FootprintDay) {
        points.removeAll { calendar.trajectoryDayID(for: $0.timestamp) == day.id }
        selectedDayID = days.first?.id
        persist()
    }

    func clearAll() {
        points.removeAll()
        selectedDayID = nil
        persist()
    }

    func exportGPX(for day: FootprintDay? = nil) -> URL? {
        let exportPoints = day?.points ?? points
        guard !exportPoints.isEmpty else { return nil }

        let fileName = day.map { "trajectory-\($0.id).gpx" } ?? "trajectory-all.gpx"
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let document = GPXBuilder.document(
            points: exportPoints,
            name: day.map { "Trajectory \($0.id)" } ?? "Trajectory All"
        )

        do {
            try document.write(to: exportURL, atomically: true, encoding: .utf8)
            lastStorageError = nil
            return exportURL
        } catch {
            lastStorageError = "GPX 导出失败：\(error.localizedDescription)"
            return nil
        }
    }

    private func shouldAccept(_ point: TrajectoryPoint) -> Bool {
        guard point.horizontalAccuracy >= 0, point.horizontalAccuracy <= 150 else {
            return false
        }

        guard let previous = points.last else {
            return true
        }

        let meters = point.distance(to: previous)
        if meters < stationaryDistanceThreshold {
            return false
        }

        return true
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(points)
            try data.write(to: fileURL, options: [.atomic])
            lastStorageError = nil
        } catch {
            lastStorageError = "轨迹保存失败：\(error.localizedDescription)"
        }
    }

    private static func defaultStoreURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Trajectory", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("footprints.json")
    }

    private static func loadPoints(from url: URL, decoder: JSONDecoder) -> [TrajectoryPoint] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        do {
            return try decoder.decode([TrajectoryPoint].self, from: data)
                .sorted { $0.timestamp < $1.timestamp }
        } catch {
            return []
        }
    }
}

private enum GPXBuilder {
    static func document(points: [TrajectoryPoint], name: String) -> String {
        let formatter = ISO8601DateFormatter()
        let body = points.map { point in
            """
            <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
              <ele>\(point.altitude)</ele>
              <time>\(formatter.string(from: point.timestamp))</time>
            </trkpt>
            """
        }
        .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Trajectory" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>\(xmlEscaped(name))</name>
            <trkseg>
        \(body)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    private static func xmlEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
