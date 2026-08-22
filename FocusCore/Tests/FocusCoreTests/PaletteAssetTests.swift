import XCTest
@testable import FocusCore

/// `Palette` 는 Color Set 을 **문자열 이름**으로 참조한다(§10). 이름이 어긋나도
/// 컴파일은 통과하고, 실행 시점에 색만 조용히 틀어진다. 그 구멍을 여기서 막는다.
///
/// 소스 트리의 `Shared/Colors.xcassets` 를 직접 읽어서 테마 × 토큰 조합이 전부
/// 존재하는지, 각각 라이트/다크 두 벌인지, 그리고 **대비가 읽을 만한지** 확인한다.
final class PaletteAssetTests: XCTestCase {

    /// `Palette` 가 참조하는 토큰 전부. Palette 에 토큰을 추가하면 여기에도 추가한다.
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
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var colorsCatalog: URL {
        repositoryRoot.appendingPathComponent("Shared/Colors.xcassets")
    }

    private func contentsURL(theme: PaletteTheme, token: String) -> URL {
        colorsCatalog
            .appendingPathComponent("\(theme.assetName(token)).colorset")
            .appendingPathComponent("Contents.json")
    }

    // MARK: - 존재와 이름

    /// 테마를 추가하고 에셋을 안 만들면 그 테마 전체가 기본색으로 떨어진다.
    func testEveryThemeAndTokenHasAColorSet() {
        for theme in PaletteTheme.allCases {
            for token in tokenNames {
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: contentsURL(theme: theme, token: token).path),
                    "Color Set '\(theme.assetName(token))' 이 없습니다. Palette 의 이름 조립과 에셋 이름이 어긋났습니다."
                )
            }
        }
    }

    func testEveryColorSetDefinesBothLightAndDark() throws {
        for theme in PaletteTheme.allCases {
            for token in tokenNames {
                let entries = try colorEntries(theme: theme, token: token)

                let dark = entries.filter { entry in
                    guard let appearances = entry["appearances"] as? [[String: Any]] else { return false }
                    return appearances.contains { $0["value"] as? String == "dark" }
                }
                let light = entries.filter { $0["appearances"] == nil }

                XCTAssertEqual(light.count, 1, "'\(theme.assetName(token))' 의 기본(라이트) 색이 정확히 하나여야 합니다.")
                XCTAssertEqual(dark.count, 1, "'\(theme.assetName(token))' 에 다크 대응 색이 없습니다. 다크모드에서 색이 깨집니다(§13-4).")
            }
        }
    }

    // MARK: - 대비

    /// 이전 팔레트는 보조 텍스트 대비가 2.9:1 이라 WCAG 최소선(3.0)에도 못 미쳤다.
    /// 눈금 숫자·캡션·메모가 전부 그 색이었다. 눈으로는 잘 안 잡히는 종류의 결함이라
    /// 수치로 못박는다.
    func testTextContrastIsReadableInBothAppearances() throws {
        for theme in PaletteTheme.allCases {
            for appearance in ["light", "dark"] {
                let background = try rgb(theme: theme, token: "background", appearance: appearance)

                for token in ["ink", "inkSecondary"] {
                    let foreground = try rgb(theme: theme, token: token, appearance: appearance)
                    let ratio = Self.contrastRatio(background, foreground)

                    XCTAssertGreaterThanOrEqual(
                        ratio, 4.5,
                        "\(theme.rawValue)/\(appearance) 의 \(token) 대비가 \(String(format: "%.1f", ratio)):1 입니다. 본문 기준 4.5:1 미만이면 작은 글자가 안 읽힙니다."
                    )
                }
            }
        }
    }

    /// 상태 점과 강조 요소. 글자가 아니므로 UI 기준 3.0:1 을 쓴다.
    func testAccentIsVisibleAgainstBackground() throws {
        for theme in PaletteTheme.allCases {
            for appearance in ["light", "dark"] {
                let background = try rgb(theme: theme, token: "background", appearance: appearance)
                let accent = try rgb(theme: theme, token: "accent", appearance: appearance)
                let ratio = Self.contrastRatio(background, accent)

                XCTAssertGreaterThanOrEqual(
                    ratio, 3.0,
                    "\(theme.rawValue)/\(appearance) 의 악센트 대비가 \(String(format: "%.1f", ratio)):1 입니다. 상태 점이 배경에 묻힙니다."
                )
            }
        }
    }

    // MARK: - 읽기 도구

    private func colorEntries(theme: PaletteTheme, token: String) throws -> [[String: Any]] {
        let data = try Data(contentsOf: contentsURL(theme: theme, token: token))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(json["colors"] as? [[String: Any]])
    }

    /// `appearance` 는 `"light"` 또는 `"dark"`.
    private func rgb(
        theme: PaletteTheme,
        token: String,
        appearance: String
    ) throws -> (Double, Double, Double) {
        let entries = try colorEntries(theme: theme, token: token)

        let entry = try XCTUnwrap(
            entries.first { candidate in
                let appearances = candidate["appearances"] as? [[String: Any]]
                let isDark = appearances?.contains { $0["value"] as? String == "dark" } ?? false
                return appearance == "dark" ? isDark : appearances == nil
            },
            "\(theme.assetName(token)) 에 \(appearance) 항목이 없습니다."
        )

        let color = try XCTUnwrap(entry["color"] as? [String: Any])
        let components = try XCTUnwrap(color["components"] as? [String: String])

        func channel(_ key: String) throws -> Double {
            let raw = try XCTUnwrap(components[key])
            let hex = raw.hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
            return Double(UInt8(hex, radix: 16) ?? 0) / 255
        }

        return (try channel("red"), try channel("green"), try channel("blue"))
    }

    /// WCAG 2.1 상대 휘도 대비.
    private static func contrastRatio(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func luminance(_ rgb: (Double, Double, Double)) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
    }
}
