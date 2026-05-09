import SwiftUI

struct FootprintView: View {
    @EnvironmentObject private var store: TrackStore
    @EnvironmentObject private var tracker: LocationTracker

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TrackingStatusPanel()
                OverviewStrip()

                RouteMapView(day: store.selectedDay)
                    .frame(height: 360)

                if let day = store.selectedDay {
                    DayMetricsGrid(day: day)
                    RecentPointsView(points: Array(day.points.suffix(6).reversed()))
                } else {
                    ContentUnavailableView(
                        "暂无足迹",
                        systemImage: "figure.walk",
                        description: Text("获得定位权限后，今天的路线和统计会显示在这里。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                if let message = tracker.lastMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = store.lastStorageError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("足迹")
    }
}

private struct TrackingStatusPanel: View {
    @EnvironmentObject private var store: TrackStore
    @EnvironmentObject private var tracker: LocationTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image("Trajectory")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(tracker.isTracking ? "自动记录中" : "等待定位权限")
                    .font(.title2.weight(.semibold))
                    Text(statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Label("自动记录", systemImage: "location.fill")
                        Label(tracker.accuracy.title, systemImage: "scope")
                        Label(tracker.accuracyAuthorizationText, systemImage: "dot.radiowaves.left.and.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                }

                Spacer()

                Circle()
                    .fill(tracker.isTracking ? Color.green : Color.secondary)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            }

            if tracker.permissionIssue == .needsAlwaysAuthorization {
                Button {
                    tracker.requestPermission()
                } label: {
                    Label("继续授权定位", systemImage: "location.badge.plus")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if !tracker.canTrackInBackground {
                Label("后台记录需要系统定位权限为“始终允许”。", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let startedAt = tracker.trackingStartedAt {
                Text("本次记录开始于 \(startedAt, style: .time)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusLine: String {
        let pointText = TrajectoryFormatter.coordinate(store.lastPoint)
        if tracker.isPausedBySystem {
            return "系统已暂缓定位，最后位置 \(pointText)"
        }
        return "权限 \(tracker.authorizationText)，最后位置 \(pointText)"
    }
}

private struct RecentPointsView: View {
    let points: [TrajectoryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近记录")
                .font(.headline)

            if points.isEmpty {
                Text("暂无定位点")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 0) {
                    ForEach(points) { point in
                        HStack(spacing: 12) {
                            Image(systemName: "location")
                                .foregroundStyle(.orange)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(TrajectoryFormatter.coordinate(point))
                                    .font(.subheadline.weight(.medium))
                                Text(point.timestamp, style: .time)
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
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct OverviewStrip: View {
    @EnvironmentObject private var store: TrackStore

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            MetricTile(
                title: "总里程",
                value: TrajectoryFormatter.distance(store.totalDistanceMeters),
                systemImage: "map.fill",
                tint: .orange
            )
            MetricTile(
                title: "本月",
                value: TrajectoryFormatter.distance(store.thisMonthDistanceMeters),
                systemImage: "calendar",
                tint: .blue
            )
            MetricTile(
                title: "记录天数",
                value: "\(store.days.count)",
                systemImage: "calendar.badge.clock",
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
