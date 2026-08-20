import XCTest
@testable import FocusCore

/// `Palette` 는 Color Set 을 **문자열 이름**으로 참조한다(§10). 이름이 어긋나도
/// 컴파일은 통과하고, 실행 시점에 색만 조용히 틀어진다. 그 구멍을 여기서 막는다.
///
/// 소스 트리의 `Shared/Colors.xcassets` 를 직접 읽어서
/// (1) 6개 토큰이 전부 존재하는지, (2) 각각 라이트/다크 두 벌을 갖고 있는지 확인한다.
final class PaletteAssetTests: XCTestCase {

    /// `Palette` 가 참조하는 Color Set 이름 전부.
    /// Palette 에 토큰을 추가하면 이 목록에도 추가해야 한다.
    private let tokenNames = [
        "background",
        "ink",
        "inkSecondary",
        "stroke",
        "handle",
        "accent"
    ]

    /// 이 파일 기준으로 리포지터리 루트를 되짚는다.
    /// FocusCore/Tests/FocusCoreTests/<이 파일> → 네 단계 위가 루트.
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FocusCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // FocusCore
            .deletingLastPathComponent()   // <루트>
    }

    private var colorsCatalog: URL {
        repositoryRoot.appendingPathComponent("Shared/Colors.xcassets")
    }

    func testEveryPaletteTokenHasAColorSet() throws {
        for name in tokenNames {
            let contents = colorsCatalog
                .appendingPathComponent("\(name).colorset")
                .appendingPathComponent("Contents.json")

            XCTAssertTrue(
                FileManager.default.fileExists(atPath: contents.path),
                "Color Set '\(name)' 이 Shared/Colors.xcassets 에 없습니다. Palette 의 이름과 에셋 이름이 어긋났습니다."
            )
        }
    }

    func testEveryColorSetDefinesBothLightAndDark() throws {
        for name in tokenNames {
            let contents = colorsCatalog
                .appendingPathComponent("\(name).colorset")
                .appendingPathComponent("Contents.json")

            let data = try Data(contentsOf: contents)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any],
                "\(name).colorset/Contents.json 파싱 실패"
            )
            let entries = try XCTUnwrap(json["colors"] as? [[String: Any]])

            let darkEntries = entries.filter { entry in
                guard let appearances = entry["appearances"] as? [[String: Any]] else { return false }
                return appearances.contains { $0["value"] as? String == "dark" }
            }
            let lightEntries = entries.filter { $0["appearances"] == nil }

            XCTAssertEqual(lightEntries.count, 1, "'\(name)' 의 기본(라이트) 색이 정확히 하나여야 합니다.")
            XCTAssertEqual(darkEntries.count, 1, "'\(name)' 에 다크 대응 색이 없습니다. 다크모드에서 색이 깨집니다(§13-4).")
        }
    }
}
