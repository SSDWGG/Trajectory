import MapKit
import SwiftUI

struct RouteMapView: View {
    let day: FootprintDay?
    @State private var position: MapCameraPosition = .automatic

    private var routeSegments: [RouteSegment] {
        guard let points = day?.points, points.count > 1 else { return [] }

        return zip(points, points.dropFirst()).map { previous, current in
            RouteSegment(
                id: "\(previous.id)-\(current.id)",
                coordinates: [previous.coordinate, current.coordinate]
            )
        }
    }

    var body: some View {
        Map(position: $position) {
            if let day {
                ForEach(routeSegments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }

                ForEach(day.points) { point in
                    Annotation("记录点", coordinate: point.coordinate) {
                        RoutePointDot()
                    }
                }

                if let start = day.coordinates.first {
                    Annotation("起点", coordinate: start) {
                        MapBadge(systemImage: "flag.fill", color: .green)
                    }
                }

                if let end = day.coordinates.last, day.coordinates.count > 1 {
                    Annotation("终点", coordinate: end) {
                        MapBadge(systemImage: "mappin", color: .red)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if day?.points.isEmpty ?? true {
                ContentUnavailableView(
                    "暂无路线",
                    systemImage: "map",
                    description: Text("记录足迹后会自动绘制路线。")
                )
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear(perform: updateCamera)
        .onChange(of: day?.id) {
            updateCamera()
        }
        .onChange(of: day?.points.count) {
            updateCamera()
        }
    }

    private func updateCamera() {
        guard let coordinates = day?.coordinates, let first = coordinates.first else {
            position = .automatic
            return
        }

        guard coordinates.count > 1 else {
            position = .region(
                MKCoordinateRegion(
                    center: first,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
            return
        }

        let rect = coordinates.reduce(MKMapRect.null) { partial, coordinate in
            partial.union(Self.rect(for: coordinate))
        }
        let paddingX = max(rect.size.width * 0.18, 800)
        let paddingY = max(rect.size.height * 0.18, 800)
        position = .rect(rect.insetBy(dx: -paddingX, dy: -paddingY))
    }

    private static func rect(for coordinate: CLLocationCoordinate2D) -> MKMapRect {
        let point = MKMapPoint(coordinate)
        return MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
    }
}

private struct RouteSegment: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
}

private struct RoutePointDot: View {
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 9, height: 9)
            .overlay {
                Circle()
                    .stroke(.orange, lineWidth: 3)
            }
            .shadow(radius: 2, y: 1)
    }
}

struct LifetimeMapView: View {
    let days: [FootprintDay]
    @State private var position: MapCameraPosition = .automatic

    private var orderedDays: [FootprintDay] {
        days.sorted { $0.date < $1.date }
    }

    private var allCoordinates: [CLLocationCoordinate2D] {
        orderedDays.flatMap(\.coordinates)
    }

    var body: some View {
        Map(position: $position) {
            ForEach(orderedDays) { day in
                if day.coordinates.count > 1 {
                    MapPolyline(coordinates: day.coordinates)
                        .stroke(.orange.opacity(0.58), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }

            if let first = allCoordinates.first {
                Annotation("第一站", coordinate: first) {
                    MapBadge(systemImage: "flag.fill", color: .green)
                }
            }

            if let last = allCoordinates.last, allCoordinates.count > 1 {
                Annotation("最近", coordinate: last) {
                    MapBadge(systemImage: "location.fill", color: .red)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if allCoordinates.isEmpty {
                ContentUnavailableView(
                    "暂无足迹",
                    systemImage: "map",
                    description: Text("获得定位权限后会生成总览地图。")
                )
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear(perform: updateCamera)
        .onChange(of: allCoordinates.count) {
            updateCamera()
        }
    }

    private func updateCamera() {
        guard let first = allCoordinates.first else {
            position = .automatic
            return
        }

        guard allCoordinates.count > 1 else {
            position = .region(
                MKCoordinateRegion(
                    center: first,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
            return
        }

        let rect = allCoordinates.reduce(MKMapRect.null) { partial, coordinate in
            partial.union(Self.rect(for: coordinate))
        }
        let paddingX = max(rect.size.width * 0.18, 1_000)
        let paddingY = max(rect.size.height * 0.18, 1_000)
        position = .rect(rect.insetBy(dx: -paddingX, dy: -paddingY))
    }

    private static func rect(for coordinate: CLLocationCoordinate2D) -> MKMapRect {
        let point = MKMapPoint(coordinate)
        return MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
    }
}

private struct MapBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .shadow(radius: 4, y: 2)
    }
}
