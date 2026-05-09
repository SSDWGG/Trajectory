import Charts
import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: TrackStore
    @State private var routeRangeMode: RouteRangeMode = .last7Days
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var customEndDate = Date()

    private let calendar = Calendar.current

    private var recentDays: [FootprintDay] {
        Array(store.days.prefix(14).reversed())
    }

    private var selectedRouteInterval: DateInterval {
        let now = Date()

        switch routeRangeMode {
        case .last7Days:
            let startDate = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            return DateInterval(start: calendar.startOfDay(for: startDate), end: now)
        case .last30Days:
            let startDate = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            return DateInterval(start: calendar.startOfDay(for: startDate), end: now)
        case .custom:
            return DateInterval(start: min(customStartDate, customEndDate), end: max(customStartDate, customEndDate))
        }
    }

    private var selectedRouteDays: [FootprintDay] {
        let interval = selectedRouteInterval

        return store.days.compactMap { day in
            let points = day.points.filter { point in
                point.timestamp >= interval.start && point.timestamp <= interval.end
            }
            guard !points.isEmpty else { return nil }
            return FootprintDay(id: day.id, date: day.date, points: points)
        }
    }

    private var selectedRouteDistance: Double {
        selectedRouteDays.reduce(0) { $0 + $1.distanceMeters }
    }

    private var selectedRoutePointCount: Int {
        selectedRouteDays.reduce(0) { $0 + $1.points.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SummaryGrid()

                VStack(alignment: .leading, spacing: 12) {
                    Text("重叠轨迹")
                        .font(.headline)

                    Picker("时间范围", selection: $routeRangeMode) {
                        ForEach(RouteRangeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if routeRangeMode == .custom {
                        VStack(spacing: 8) {
                            DatePicker("开始", selection: $customStartDate, displayedComponents: [.date, .hourAndMinute])
                            DatePicker("结束", selection: $customEndDate, displayedComponents: [.date, .hourAndMinute])
                        }
                        .font(.subheadline)
                    }

                    HStack(spacing: 14) {
                        Label("\(selectedRouteDays.count) 天", systemImage: "calendar")
                        Label(TrajectoryFormatter.distance(selectedRouteDistance), systemImage: "figure.walk")
                        Label("\(selectedRoutePointCount) 点", systemImage: "smallcircle.filled.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    LifetimeMapView(days: selectedRouteDays)
                        .frame(height: 300)
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 12) {
                    Text("近 14 天")
                        .font(.headline)

                    if recentDays.isEmpty {
                        ContentUnavailableView(
                            "暂无统计",
                            systemImage: "chart.bar",
                            description: Text("记录几段路线后会生成趋势图。")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        Chart(recentDays) { day in
                            BarMark(
                                x: .value("日期", day.date, unit: .day),
                                y: .value("公里", day.distanceMeters / 1000)
                            )
                            .foregroundStyle(.orange.gradient)
                        }
                        .chartYAxisLabel("公里")
                        .frame(height: 240)
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))

                if let longest = store.longestDay {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最长一天")
                            .font(.headline)
                        Text(longest.date, format: .dateTime.year().month().day().weekday())
                            .foregroundStyle(.secondary)
                        Text(TrajectoryFormatter.distance(longest.distanceMeters))
                            .font(.largeTitle.weight(.bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("统计")
    }
}

private enum RouteRangeMode: String, CaseIterable, Identifiable {
    case last7Days
    case last30Days
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days:
            return "7 天"
        case .last30Days:
            return "30 天"
        case .custom:
            return "自定义"
        }
    }
}

private struct SummaryGrid: View {
    @EnvironmentObject private var store: TrackStore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            MetricTile(
                title: "总里程",
                value: TrajectoryFormatter.distance(store.totalDistanceMeters),
                systemImage: "map",
                tint: .orange
            )
            MetricTile(
                title: "记录天数",
                value: "\(store.days.count)",
                systemImage: "calendar",
                tint: .blue
            )
            MetricTile(
                title: "本月",
                value: TrajectoryFormatter.distance(store.thisMonthDistanceMeters),
                systemImage: "calendar",
                tint: .green
            )
            MetricTile(
                title: "平均/天",
                value: TrajectoryFormatter.distance(store.averageDistancePerDay),
                systemImage: "chart.line.uptrend.xyaxis",
                tint: .purple
            )
        }
    }
}
