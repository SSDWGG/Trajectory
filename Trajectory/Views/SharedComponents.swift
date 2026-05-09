import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DayMetricsGrid: View {
    let day: FootprintDay

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            MetricTile(
                title: "里程",
                value: TrajectoryFormatter.distance(day.distanceMeters),
                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                tint: .orange
            )
            MetricTile(
                title: "时长",
                value: TrajectoryFormatter.duration(day.duration),
                systemImage: "clock",
                tint: .blue
            )
            MetricTile(
                title: "记录点",
                value: "\(day.points.count)",
                systemImage: "smallcircle.filled.circle",
                tint: .green
            )
            MetricTile(
                title: "平均速度",
                value: averageSpeed,
                systemImage: "speedometer",
                tint: .purple
            )
        }
    }

    private var averageSpeed: String {
        guard day.duration > 0 else { return "--" }
        return TrajectoryFormatter.speed(day.distanceMeters / day.duration)
    }
}
