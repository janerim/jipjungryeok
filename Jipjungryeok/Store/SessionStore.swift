import Foundation
import Observation
import SwiftData
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

    /// §4.2 회고 칸 수
    static let retrospectLimit = 3

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
        let targetID = record.id
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { $0.id == targetID }
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            existing.apply(record)
        } else {
            context.insert(FocusSession(record: record))
        }

        persist()
        reload()
    }

    /// §4.3 데이터 초기화. 실제 호출은 M4 설정 화면에서 연결한다.
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
        recent = fetchRecentCompleted()
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

    /// §4.2 회고는 "최근 **완료** 세션" 이므로 중도 중지한 세션은 빼고 보여준다.
    /// 통계 합계에는 들어가지만 회고 카드에는 안 나온다.
    private func fetchRecentCompleted() -> [SessionRecord] {
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { $0.isCompleted },
            sortBy: [SortDescriptor(\.endAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.retrospectLimit
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
