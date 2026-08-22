import Foundation
import Observation
import SwiftData
import WidgetKit
import FocusCore

/// 세션 저장과 통계 조회.
///
/// 스토어는 App Group 컨테이너에 둔다 (§5). 지금은 앱만 쓰지만, M5 에서 위젯이
/// 같은 컨테이너의 `UserDefaults` 스냅샷을 읽고, M6 에서 워치가 붙는다.
///
/// 집계 자체는 `FocusCore.StatsCalculator` 가 한다. 여기는 꺼내오고 넘겨주는 일만 맡는다.
@MainActor
@Observable
final class SessionStore {

    /// §4.2-3 통계 화면에 바로 보이는 최근 세션 수. 그 너머는 기록 시트로 간다.
    static let recentLimit = 5

    private(set) var summary: StatsSummary
    /// 최근 완료 세션. 회고 섹션이 쓴다.
    private(set) var recent: [SessionRecord] = []

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let calculator: StatsCalculator

    private var context: ModelContext { container.mainContext }

    /// - Parameter inMemory: 프리뷰와 테스트용. 디스크에 아무것도 남기지 않는다.
    init(inMemory: Bool = false, calendar: Calendar = .focus) {
        self.calculator = StatsCalculator(calendar: calendar)
        self.container = Self.makeContainer(inMemory: inMemory)
        self.summary = self.calculator.summarize([], now: .now)
        reload()
    }

    // MARK: - 쓰기

    /// 세션 1건을 저장한다.
    ///
    /// 같은 `id` 가 이미 있으면 덮어쓴다. 완료 처리가 두 번 불리거나(포그라운드 복귀와
    /// 1초 타이머가 겹치는 경우), 나중에 워치에서 같은 세션이 다시 올라와도(§8-1-4)
    /// 중복 행이 생기지 않는다.
    func save(_ record: SessionRecord) {
        if let existing = fetchSession(id: record.id) {
            existing.apply(record)
        } else {
            context.insert(FocusSession(record: record))
        }

        persist()
        reload()
    }

    /// §7 캘린더 기록에 성공하면 이벤트 식별자를 세션에 붙인다.
    ///
    /// 통계는 달라지지 않으므로 `reload()` 를 하지 않는다.
    func attachCalendarEvent(_ eventID: String, to sessionID: UUID) {
        guard let session = fetchSession(id: sessionID) else { return }
        session.calendarEventID = eventID
        persist()
    }

    /// 세션이 끝난 뒤 받은 메모를 붙인다.
    ///
    /// 회고 카드가 바로 바뀌어야 하므로 `reload()` 까지 한다.
    func attachMemo(_ memo: String, to sessionID: UUID) {
        guard let session = fetchSession(id: sessionID) else { return }
        session.memo = memo
        persist()
        reload()
    }

    /// 재시도 큐와 메모 대기가 id 로 세션을 되찾을 때 쓴다 (§7).
    func record(with id: UUID) -> SessionRecord? {
        fetchSession(id: id)?.record
    }

    private func fetchSession(id: UUID) -> FocusSession? {
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// §4.3 데이터 초기화.
    func deleteAll() {
        do {
            try context.delete(model: FocusSession.self)
        } catch {
            assertionFailure("세션 전체 삭제 실패: \(error)")
        }
        persist()
        reload()
    }

    // MARK: - 읽기

    /// 저장된 세션을 다시 읽어 통계를 계산한다.
    ///
    /// 통계 화면이 나타날 때, 세션이 저장될 때, 포그라운드로 복귀할 때 불린다.
    /// 마지막 경우가 중요하다 — 자정을 넘겨 돌아오면 "오늘" 이 달라져 있다.
    func reload(now: Date = .now) {
        summary = calculator.summarize(fetchSessionsInWindow(now: now), now: now)
        recent = fetchRecent()
        publishSnapshot(now: now)
    }

    /// §8.1 위젯은 SwiftData 를 열지 않고 이 스냅샷만 읽는다.
    ///
    /// `reload()` 에 붙여 둔 이유는, 통계가 갱신되는 모든 경로가 결국 여기를
    /// 지나기 때문이다. 세션 저장·삭제·자정 넘김·포그라운드 복귀에 각각
    /// 갱신 코드를 흩어 두면 그중 하나를 빠뜨렸을 때 위젯만 조용히 옛 값을 남긴다.
    private func publishSnapshot(now: Date) {
        SnapshotStore.save(summary.snapshot(updatedAt: now))
        // 타임라인 정책이 `.after(자정)` 이라 이 호출이 없으면 세션이 끝나도
        // 다음 자정까지 위젯이 그대로다 (§8.1).
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 집계에 필요한 범위만 꺼내온다. 전체를 다 읽을 이유가 없다.
    private func fetchSessionsInWindow(now: Date) -> [SessionRecord] {
        let windowStart = calculator.windowStart(for: now)
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { $0.startAt >= windowStart },
            sortBy: [SortDescriptor(\.startAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(\.record)
    }

    /// §4.2 기록 화면이 쓰는 전체 이력.
    ///
    /// 화면에 들어갈 때만 부르고 결과를 들고 있지 않는다. 세션은 한 건이 수십 바이트라
    /// 수천 건이어도 가볍고, 상시 보관하면 세션이 끝날 때마다 갱신해 줘야 한다.
    ///
    /// 정렬을 여기서 하지 않는 이유는 `SessionHistory.byDay` 가 §4.2 규칙(`startAt` 기준)에
    /// 맞춰 다시 묶고 정렬하기 때문이다. 두 곳에서 정렬하면 규칙이 갈라진다.
    func allRecords() -> [SessionRecord] {
        let descriptor = FetchDescriptor<FocusSession>()
        return ((try? context.fetch(descriptor)) ?? []).map(\.record)
    }

    /// §4.2-3 최근 세션. 중도 중지한 것도 포함한다.
    ///
    /// 예전 회고 카드는 완료된 것만 골랐지만, 지금은 이 목록이 기록 시트의 앞부분
    /// 역할을 한다. 두 곳의 기준이 다르면 "전체" 를 눌렀을 때 없던 항목이 튀어나온다.
    ///
    /// 정렬은 `startAt` 기준이다 — 날짜 판정 규칙(§4.2)과 같은 축을 써야
    /// 기록 시트의 순서와 어긋나지 않는다.
    private func fetchRecent() -> [SessionRecord] {
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.recentLimit
        return ((try? context.fetch(descriptor)) ?? []).map(\.record)
    }

    // MARK: -

    private func persist() {
        do {
            try context.save()
        } catch {
            // 저장에 실패해도 타이머는 계속 동작해야 한다. 세션 하나를 잃을 뿐이다.
            assertionFailure("세션 저장 실패: \(error)")
        }
    }

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            // §5 — App Group 컨테이너에 둬야 위젯·워치가 같은 스토어를 볼 수 있다.
            let url = AppGroup.containerURL.appendingPathComponent("Jipjungryeok.store")
            configuration = ModelConfiguration(url: url)
        }

        do {
            return try ModelContainer(for: FocusSession.self, configurations: configuration)
        } catch {
            // 스토어를 못 열면 앱이 할 수 있는 일이 없다. 조용히 빈 통계를 보여주느니
            // 원인을 드러내고 죽는 편이 낫다.
            fatalError("SwiftData 스토어를 열 수 없습니다: \(error)")
        }
    }
}
