import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: TrackStore
    @EnvironmentObject private var tracker: LocationTracker

    @State private var exportURL: URL?
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            Section("记录") {
                Picker("定位模式", selection: $tracker.accuracy) {
                    ForEach(TrackingAccuracy.allCases) { accuracy in
                        Text(accuracy.title).tag(accuracy)
                    }
                }
                Text(tracker.accuracy.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("记录间距")
                        Spacer()
                        Text("\(Int(tracker.distanceFilter)) m")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $tracker.distanceFilter, in: 10...200, step: 5)
                }

                Toggle("显示后台定位指示", isOn: $tracker.showsBackgroundIndicator)
            }

            Section("权限") {
                LabeledContent("定位权限", value: tracker.authorizationText)
                LabeledContent("精准定位", value: tracker.accuracyAuthorizationText)
                LabeledContent("后台记录", value: tracker.canTrackInBackground ? "可用" : "不可用")

                Button {
                    tracker.requestPermission()
                } label: {
                    Label("请求始终允许定位", systemImage: "location.badge.plus")
                }

                Button {
                    openSystemSettings()
                } label: {
                    Label("打开系统设置", systemImage: "gear")
                }
            }

            Section("数据") {
                LabeledContent("本地记录", value: "\(store.points.count) 个定位点")
                LabeledContent("记录天数", value: "\(store.days.count) 天")
                LabeledContent("总里程", value: TrajectoryFormatter.distance(store.totalDistanceMeters))

                Button {
                    exportURL = store.exportGPX()
                } label: {
                    Label("生成全部 GPX", systemImage: "doc.badge.arrow.up")
                }
                .disabled(store.points.isEmpty)

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("分享 GPX 文件", systemImage: "square.and.arrow.up")
                    }
                }

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("清空本地足迹", systemImage: "trash")
                }
                .disabled(store.points.isEmpty)
            }

            if let error = store.lastStorageError {
                Section("错误") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("设置")
        .confirmationDialog("清空所有足迹？", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                store.clearAll()
                exportURL = nil
            }
        } message: {
            Text("这个操作只会删除本机保存的轨迹数据。")
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
