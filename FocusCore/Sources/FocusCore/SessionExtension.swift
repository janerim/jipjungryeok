import Foundation

/// §6-7 계획한 시간이 끝난 뒤에도 이어서 일한 시간을 세션에 더한다.
///
/// 회고 시트가 떴는데 하던 일이 안 끝나 계속하는 경우가 있다. 그때 **메모를 저장한
/// 순간까지**를 세션으로 본다. 시트를 띄워 둔 채 계속 일했다는 뜻이기 때문이다.
///
/// 두 가지 안전장치가 있다. 둘 다 없으면 이 기능은 통계를 망가뜨린다.
///
/// 1. **앱을 보고 있는 상태에서 끝난 세션에만** 적용한다. 백그라운드에서 끝난 세션은
///    다음에 앱을 열 때 회고를 묻는데(§6-6), 그게 다음 날일 수도 있다. 그 경우까지
///    늘리면 10시간짜리 세션이 만들어진다. 이 판단은 호출하는 쪽이 한다.
/// 2. **늘어나는 양에 상한**을 둔다. 시트를 띄워 놓고 자리를 비웠을 수 있다.
public enum SessionExtension {

    /// 한 번에 늘어날 수 있는 최대치. 다이얼 한 바퀴와 같은 90분이다.
    ///
    /// 계획 시간의 배수로 잡지 않는 이유는, 5분 세션 뒤에 40분을 더 일한 경우
    /// 그 35분이 통째로 사라지기 때문이다.
    public static var maximumExtraSeconds: Int { TimerEngine.maximumMinutes * 60 }

    /// 원래 종료 시각 이후 흘러 세션에 더해질 초. 늘릴 것이 없으면 0.
    public static func extraSeconds(originalEnd: Date, savedAt: Date) -> Int {
        let elapsed = Int(savedAt.timeIntervalSince(originalEnd))
        guard elapsed > 0 else { return 0 }
        return min(elapsed, maximumExtraSeconds)
    }

    /// 연장이 반영된 종료 시각.
    public static func extendedEnd(originalEnd: Date, savedAt: Date) -> Date {
        originalEnd.addingTimeInterval(Double(extraSeconds(originalEnd: originalEnd, savedAt: savedAt)))
    }

    /// 연장이 반영된 실제 집중 시간.
    ///
    /// 일시정지가 있었다면 `actualSeconds` 는 `endAt - startAt` 보다 짧다. 그래서
    /// 종료 시각으로 다시 계산하지 않고 원래 값에 더한다 — 안 그러면 멈춰 있던
    /// 시간까지 집중한 것으로 잡힌다.
    public static func extendedActualSeconds(
        original: SessionRecord,
        savedAt: Date
    ) -> Int {
        original.actualSeconds + extraSeconds(originalEnd: original.endAt, savedAt: savedAt)
    }
}
