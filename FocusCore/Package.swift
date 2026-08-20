// swift-tools-version: 5.9
import PackageDescription

/// 플랫폼 독립 공유 로직 (§9).
///
/// 여기에 들어가는 것: 모델, TimerEngine, 통계 집계, 디자인 토큰, 스냅샷 포맷.
/// 여기에 들어가지 않는 것: 화면, 제스처 입력, EventKit, WidgetKit, WatchConnectivity.
///
/// watchOS 는 1차 범위에서 제외지만(§8-1), 패키지 분리 자체는 처음부터 해둔다.
/// M1 에서 TimerEngine 을 앱 타겟 안에 넣어버리면 나중에 워치를 붙일 때 전부 뜯어내야 한다.
let package = Package(
    name: "FocusCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "FocusCore", targets: ["FocusCore"])
    ],
    targets: [
        .target(name: "FocusCore"),
        .testTarget(name: "FocusCoreTests", dependencies: ["FocusCore"])
    ]
)
