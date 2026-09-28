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
        .iOS(.v15),
        .watchOS(.v10),
        // 앱은 macOS 에서 돌지 않지만, `swift test` 는 호스트(macOS)용으로 빌드한다.
        // 이 선언이 없으면 배포 타깃이 10.13 으로 떨어져 Color(10.15+)·Date.now(12+) 가
        // 전부 "only available in macOS ..." 로 막히고, 시뮬레이터 없이 로직만 검증하는
        // 이 패키지의 존재 이유가 사라진다.
        //
        // iOS 15 와 같은 해에 나온 macOS 12 로 맞춘다. 14 로 두면 iOS 16·17 전용 API 를
        // 써도 `swift test` 가 통과해서, 아이폰 6s 빌드에서야 드러난다.
        .macOS(.v12)
    ],
    products: [
        .library(name: "FocusCore", targets: ["FocusCore"])
    ],
    targets: [
        .target(name: "FocusCore"),
        .testTarget(name: "FocusCoreTests", dependencies: ["FocusCore"])
    ]
)
