import Foundation

/// §4.3 기록 내보내기/가져오기 파일.
///
/// 폰 두 대에서 쓰는 사람이 기록을 한쪽으로 모으기 위한 것이다. 클라우드 동기화는
/// 만들지 않기로 했으므로(§3) 사용자가 파일을 직접 옮긴다(AirDrop, 파일 앱).
///
/// 파일 형식과 합치는 규칙을 화면이 아니라 여기 두는 이유: 한 번 내보낸 파일은 고칠 수
/// 없어서 형식이 조용히 바뀌면 안 되고, 중복을 거르는 규칙이 틀어지면 통계가 두 배가 된다.
/// 둘 다 화면을 띄워 봐야 드러나는 종류라 단위 테스트로 못박는다.
public struct SessionArchive: Codable, Equatable, Sendable {

    /// 형식을 바꾸면 올린다. 모르는 버전은 읽지 않는다 — 필드 뜻이 달라졌을 수 있는데
    /// 그대로 읽으면 엉뚱한 값이 통계에 섞인다.
    public static let currentVersion = 1

    public let version: Int

    /// 내보낸 시각. 파일 이름에 쓰고, 나중에 "언제 파일이지" 를 확인할 때 본다.
    public let exportedAt: Date

    /// 끝난 세션 전부. 진행 중인 세션과 설정은 넣지 않는다.
    ///
    /// 캘린더 이벤트 식별자도 들어가지 않는다(`SessionRecord` 에 없다). 그 기기의 캘린더에서만
    /// 뜻이 있는 값이다.
    public let sessions: [SessionRecord]

    public init(sessions: [SessionRecord], exportedAt: Date) {
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        // 시작 시각 순으로 둔다. 파일을 열어 봤을 때 읽히고, 같은 기록이면 같은 파일이 나온다.
        self.sessions = sessions.sorted { $0.startAt < $1.startAt }
    }

    // MARK: - 파일

    public enum ReadError: Error, Equatable {
        /// 이 앱이 만든 파일이지만 더 새 버전이 만든 것.
        case unsupportedVersion(Int)
    }

    public func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    /// 다른 앱의 JSON 이거나 깨진 파일이면 `DecodingError` 를 던진다.
    public static func decode(_ data: Data) throws -> SessionArchive {
        let archive = try decoder.decode(SessionArchive.self, from: data)
        guard archive.version == currentVersion else {
            throw ReadError.unsupportedVersion(archive.version)
        }
        return archive
    }

    /// 날짜는 1970 기준 초로 쓴다. ISO 8601 은 읽기 좋지만 `JSONEncoder` 기본 구현이
    /// 초 미만을 버린다. 그 정도는 통계에 영향이 없지만, 넣었다 뺀 값이 달라지는 형식은
    /// 테스트로 못박기 어렵다.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// `jipjungryeok-20261002.json`
    ///
    /// 파일 이름은 영문으로 둔다(파일·타겟명과 같은 규칙 6). 날짜만 있으면 어느 파일인지
    /// 충분히 알아본다.
    public func suggestedFileName(calendar: Calendar = .focus) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: exportedAt)
        let stamp = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "jipjungryeok-\(stamp).json"
    }

    // MARK: - 합치기

    /// 가져올 때 실제로 넣을 세션. **이미 있는 세션은 건드리지 않는다.**
    ///
    /// 기록에는 "언제 고쳤는지" 가 없어서 같은 세션이 양쪽에 있으면 어느 쪽이 최신인지
    /// 알 수 없다. 덮어쓰면 받는 폰에서 고친 메모가 사라질 수 있으므로, 받는 쪽을 그대로 둔다.
    /// 같은 파일을 두 번 가져와도 아무 일도 일어나지 않는 것은 이 규칙 덕분이다.
    ///
    /// 파일 안에 같은 세션이 두 번 있어도(손으로 고친 파일 등) 한 번만 넣는다.
    public func newSessions(excluding existingIDs: Set<UUID>) -> [SessionRecord] {
        var seen = existingIDs
        return sessions.filter { seen.insert($0.id).inserted }
    }
}
