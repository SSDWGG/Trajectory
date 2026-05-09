import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: TrackStore

    var body: some View {
        Group {
            if store.days.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "calendar.badge.clock",
                    description: Text("每天的足迹会自动归档在这里。")
                )
            } else {
                List {
                    ForEach(store.days) { day in
                        NavigationLink {
                            HistoryDayDetailView(dayID: day.id)
                                .onAppear {
                                    store.select(day)
                                }
                        } label: {
                            DayRow(day: day)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(day)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("日历")
    }
}

private struct DayRow: View {
    let day: FootprintDay

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(day.date, format: .dateTime.day())
                    .font(.title2.weight(.bold))
                Text(day.date, format: .dateTime.month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 54)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(day.date, format: .dateTime.year().month().day().weekday())
                    .font(.headline)
                HStack(spacing: 14) {
                    Label(TrajectoryFormatter.distance(day.distanceMeters), systemImage: "figure.walk")
                    Label("\(day.points.count) 点", systemImage: "smallcircle.filled.circle")
                    Label(TrajectoryFormatter.duration(day.duration), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

private struct HistoryDayDetailView: View {
    @EnvironmentObject private var store: TrackStore
    let dayID: String

    private var day: FootprintDay? {
        store.days.first { $0.id == dayID }
    }

    var body: some View {
        Group {
            if let day {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.date, format: .dateTime.year().month().day().weekday())
                                .font(.title2.weight(.semibold))
                            Text("\(timeText(day.startTime)) - \(timeText(day.endTime))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        RouteMapView(day: day)
                            .frame(height: 340)

                        DayMetricsGrid(day: day)
                        MovementDetailSection(day: day)
                        RoutePointTimeline(points: day.points)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    "记录已删除",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("这一天的轨迹数据已经不在本机。")
                )
            }
        }
        .navigationTitle("当天详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MovementDetailSection: View {
    let day: FootprintDay

    private var maxSpeedText: String {
        let validSpeeds = day.points.map(\.speed).filter { $0 >= 0 }
        guard let maxSpeed = validSpeeds.max() else { return "--" }
        return TrajectoryFormatter.speed(maxSpeed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("运动数据")
                .font(.headline)

            VStack(spacing: 0) {
                DetailRow(title: "开始时间", value: timeText(day.startTime))
                Divider()
                DetailRow(title: "结束时间", value: timeText(day.endTime))
                Divider()
                DetailRow(title: "最高速度", value: maxSpeedText)
                Divider()
                DetailRow(title: "起点", value: TrajectoryFormatter.coordinate(day.points.first))
                Divider()
                DetailRow(title: "终点", value: TrajectoryFormatter.coordinate(day.points.last))
            }
            .padding(.horizontal, 14)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct RoutePointTimeline: View {
    let points: [TrajectoryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("轨迹点")
                .font(.headline)

            LazyVStack(spacing: 0) {
                ForEach(points) { point in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "location")
                                .foregroundStyle(.orange)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(TrajectoryFormatter.coordinate(point))
                                    .font(.subheadline.weight(.medium))
                                Text("\(timeText(point.timestamp))  \(TrajectoryFormatter.speed(point.speed))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("±\(Int(point.horizontalAccuracy))m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)

                        if point.id != points.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
    }
}

private func timeText(_ date: Date?) -> String {
    guard let date else { return "--" }
    return date.formatted(date: .omitted, time: .shortened)
}
