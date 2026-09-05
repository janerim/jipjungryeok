import XCTest
@testable import FocusCore

/// §6-4 · §6-7 세션이 끝난 방식에 따라 회고를 묻는지, 늘려도 되는지.
///
/// 이 두 판단이 틀리면 화면을 띄워 봐야만 드러난다 — 회고가 안 뜨거나(사용자에게는
/// 기록이 사라진 것으로 보인다), 다이얼을 돌리는 도중에 시트가 튀어나온다.
final class SessionEndingTests: XCTestCase {

    // MARK: - 회고를 묻는지

    func testCompletedSessionAsksMemo() {
        XCTAssertTrue(SessionEnding.completed(endedWhileActive: true).asksMemo)
        XCTAssertTrue(SessionEnding.completed(endedWhileActive: false).asksMemo)
    }

    /// 중지도 묻는다. 회의에 불려 가 멈춘 경우 남길 곳이 여기뿐이다.
    func testStoppedSessionAsksMemo() {
        XCTAssertTrue(SessionEnding.stopped.asksMemo)
    }

    /// 다이얼을 돌려 새 시간을 맞추는 손동작 한가운데에 시트가 뜨면 방해다.
    func testReplacedSessionDoesNotAskMemo() {
        XCTAssertFalse(SessionEnding.replaced.asksMemo)
    }

    // MARK: - §6-7 연장

    /// 앱을 보고 있는 중에 끝난 완료 세션만 늘린다.
    func testOnlyForegroundCompletionAllowsExtension() {
        XCTAssertTrue(SessionEnding.completed(endedWhileActive: true).allowsExtension)
        XCTAssertFalse(SessionEnding.completed(endedWhileActive: false).allowsExtension)
    }

    /// 중지는 그만두겠다는 뜻이다. 사유를 적는 동안 흐른 시간을 집중 시간에 더하면
    /// 자리를 뜬 시간이 기록에 들어간다.
    func testStoppedSessionNeverExtends() {
        XCTAssertFalse(SessionEnding.stopped.allowsExtension)
    }

    func testReplacedSessionNeverExtends() {
        XCTAssertFalse(SessionEnding.replaced.allowsExtension)
    }
}
