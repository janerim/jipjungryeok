import XCTest
@testable import FocusCore

/// §4.3 기록 내보내기/가져오기.
///
/// 한 번 내보낸 파일은 고칠 수 없으므로 형식을 고정 JSON 으로 못박는다.
/// 날짜는 초 단위로만 만든다 — 1970 기준 초로 바꾸는 과정에서 초 미만이 흔들리면
/// 넣었다 뺀 값의 비교가 의미 없어진다.
final class SessionArchiveTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar.focus
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func record(
        id: UUID = UUID(),
        startAt: Date,
        seconds: Int = 1500,
        completed: Bool = true,
        memo: String? = nil
    ) -> SessionRecord {
        SessionRecord(
            id: id,
            startAt: startAt,
            endAt: startAt.addingTimeInterval(Double(seconds)),
            plannedSeconds: 1500,
            actualSeconds: seconds,
            isCompleted: completed,
            memo: memo
        )
    }

    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    // MARK: - 파일 형식

    /// 내보낸 파일을 다시 읽으면 모든 필드가 그대로다. 메모가 없는 세션도 포함.
    func testRoundTripKeepsEveryField() throws {
        let sessions = [
            record(startAt: t0, memo: "기획서 §7 읽기"),
            record(startAt: t0.addingTimeInterval(3600), seconds: 600, completed: false, memo: nil),
        ]
        let archive = SessionArchive(sessions: sessions, exportedAt: t0.addingTimeInterval(7200))

        let decoded = try SessionArchive.decode(archive.encoded())

        XCTAssertEqual(decoded, archive)
        XCTAssertEqual(decoded.sessions, sessions)
    }

    /// 1.3 에서 내보낸 형식. 이 테스트가 깨지면 **이미 내보낸 파일을 못 읽게 된다.**
    /// 필드 이름을 바꾸고 싶으면 `currentVersion` 을 올리고 옛 형식을 읽는 길을 따로 둘 것.
    func testDecodesVersionOneFixture() throws {
        let json = """
        {
          "exportedAt" : 1790007200,
          "sessions" : [
            {
              "actualSeconds" : 1500,
              "endAt" : 1790001500,
              "id" : "6F9619FF-8B86-D011-B42D-00C04FC964FF",
              "isCompleted" : true,
              "memo" : "회의 준비",
              "plannedSeconds" : 1500,
              "startAt" : 1790000000
            }
          ],
          "version" : 1
        }
        """

        let archive = try SessionArchive.decode(Data(json.utf8))

        XCTAssertEqual(archive.exportedAt, t0.addingTimeInterval(7200))
        XCTAssertEqual(archive.sessions, [
            SessionRecord(
                id: UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!,
                startAt: t0,
                endAt: t0.addingTimeInterval(1500),
                plannedSeconds: 1500,
                actualSeconds: 1500,
                isCompleted: true,
                memo: "회의 준비"
            )
        ])
    }

    /// 메모가 없는 세션은 `memo` 키가 아예 없어도 읽힌다.
    func testDecodesSessionWithoutMemoKey() throws {
        let json = """
        {"version":1,"exportedAt":1790007200,"sessions":[
          {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","startAt":1790000000,"endAt":1790000600,
           "plannedSeconds":1500,"actualSeconds":600,"isCompleted":false}
        ]}
        """

        let archive = try SessionArchive.decode(Data(json.utf8))

        XCTAssertNil(archive.sessions.first?.memo)
    }

    /// 더 새 버전의 앱이 만든 파일은 읽지 않는다. 필드 뜻이 달라졌을 수 있다.
    func testRejectsUnknownVersion() {
        let json = #"{"version":2,"exportedAt":1790007200,"sessions":[]}"#

        XCTAssertThrowsError(try SessionArchive.decode(Data(json.utf8))) { error in
            XCTAssertEqual(error as? SessionArchive.ReadError, .unsupportedVersion(2))
        }
    }

    /// 이 앱이 만든 파일이 아니면 실패한다. 빈 기록으로 조용히 넘어가면 안 된다.
    func testRejectsUnrelatedJSON() {
        let json = #"{"name":"something else"}"#

        XCTAssertThrowsError(try SessionArchive.decode(Data(json.utf8)))
    }

    /// 세션은 시작 시각 순으로 담긴다. 같은 기록이면 같은 파일이 나온다.
    func testSessionsAreSortedByStart() {
        let later = record(startAt: t0.addingTimeInterval(3600))
        let earlier = record(startAt: t0)

        let archive = SessionArchive(sessions: [later, earlier], exportedAt: t0)

        XCTAssertEqual(archive.sessions.map(\.id), [earlier.id, later.id])
    }

    func testSuggestedFileNameUsesExportDateInLocalTime() {
        // 2026-10-02 00:30 KST 는 UTC 로 10-01 15:30 이다. 기기 시간대로 계산해야
        // 사용자가 내보낸 날짜(10월 2일)가 파일 이름에 찍힌다.
        var parts = DateComponents()
        parts.year = 2026; parts.month = 10; parts.day = 2; parts.hour = 0; parts.minute = 30
        let justAfterMidnight = calendar.date(from: parts)!

        let archive = SessionArchive(sessions: [], exportedAt: justAfterMidnight)

        XCTAssertEqual(archive.suggestedFileName(calendar: calendar), "jipjungryeok-20261002.json")
    }

    // MARK: - 합치기

    /// 받는 폰에 이미 있는 세션은 넣지 않는다. 같은 파일을 두 번 가져와도 통계가 두 배가 되지 않는다.
    func testNewSessionsSkipsExistingIDs() {
        let existing = record(startAt: t0)
        let fresh = record(startAt: t0.addingTimeInterval(3600))
        let archive = SessionArchive(sessions: [existing, fresh], exportedAt: t0)

        let result = archive.newSessions(excluding: [existing.id])

        XCTAssertEqual(result, [fresh])
    }

    /// 이미 있는 세션은 메모가 달라도 넣지 않는다 — 받는 쪽에서 고친 메모를 지키기 위해서다.
    func testExistingSessionIsKeptEvenIfMemoDiffers() {
        let id = UUID()
        let archive = SessionArchive(sessions: [record(id: id, startAt: t0, memo: "보낸 쪽 메모")], exportedAt: t0)

        XCTAssertTrue(archive.newSessions(excluding: [id]).isEmpty)
    }

    /// 파일 안에 같은 세션이 두 번 있어도 한 번만 넣는다.
    func testNewSessionsDeduplicatesWithinFile() {
        let session = record(startAt: t0)
        let archive = SessionArchive(sessions: [session, session], exportedAt: t0)

        XCTAssertEqual(archive.newSessions(excluding: []), [session])
    }

    func testEmptyArchiveAddsNothing() {
        let archive = SessionArchive(sessions: [], exportedAt: t0)

        XCTAssertTrue(archive.newSessions(excluding: []).isEmpty)
    }
}
