# Trajectory

Trajectory 是一个 iOS 足迹记录应用。它会在获得定位权限后自动记录运动轨迹，把每天的路线、里程、时长和定位点整理成可回看的本地足迹档案。

项目主页：<https://ssdwgg.github.io/Trajectory/>

## 功能特性

- 自动记录当前位置并绘制当天路线
- 按日期归档历史足迹，支持查看当天详情
- 统计总里程、本月里程、记录天数和近 14 天趋势
- 支持多天轨迹叠加查看
- 可调定位精度、记录间距和后台定位指示
- 本地保存轨迹数据，支持导出 GPX 文件

## 技术栈

- SwiftUI
- MapKit
- CoreLocation
- Charts
- iOS 17+

## 本地运行

1. 用 Xcode 打开 `Trajectory.xcodeproj`
2. 选择 `Trajectory` scheme
3. 选择 iOS 17 或更高版本的真机或模拟器
4. 构建并运行

应用依赖定位权限。为了后台持续记录路线，需要在系统设置中允许 Trajectory 始终访问定位。

## 数据与隐私

Trajectory 的轨迹数据默认保存在本机 Application Support 目录下，不依赖远程服务器。你可以在应用内清空本地足迹，也可以导出 GPX 文件自行保存或分享。

## GitHub Pages

落地页源码位于 `docs/` 目录，并通过 GitHub Pages 从 `main` 分支的 `/docs` 发布。
