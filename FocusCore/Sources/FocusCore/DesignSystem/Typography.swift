import SwiftUI

/// §10 타이포그래피. 폰트는 SF Pro(시스템)만 쓴다.
public enum Typography {

    /// 다이얼 하단 남은 시간 숫자.
    ///
    /// 주인공은 다이얼이지 숫자가 아니다. 숫자를 키우면 시선이 아래로 끌려가고
    /// 다이얼에 쓸 세로 공간도 그만큼 줄어든다.
    public static let countdown = Font.system(size: 32, weight: .bold, design: .rounded)

    /// 화면 상단 상태 표시 (`🎯 집중`).
    ///
    /// 세션 종류가 하나뿐이라 이 줄은 정보량이 적지만, 화면에서 유일한 글자 제목이라
    /// `.headline`(17pt) 로는 여백에 파묻힌다.
    public static let statusLabel = Font.system(size: 22, weight: .semibold, design: .rounded)

    /// 시트 제목 (`25분 집중 완료`).
    ///
    /// 상단 상태 표시와 크기를 공유하던 것을 분리했다. 시트는 폭이 좁고 오른쪽에
    /// 닫기 버튼이 붙어서 같이 키우면 줄이 밀린다.
    public static let sheetTitle = Font.system(.headline, design: .rounded)

    /// 통계 추이 카드의 값 (`00:35`)
    public static let statValue = Font.system(size: 22, weight: .semibold, design: .rounded)

    /// 통계 추이 카드의 항목명 (`오늘`, `이번 주` …)
    public static let statCaption = Font.system(.caption, design: .rounded)

    /// 다이얼 눈금 숫자 라벨 (0, 15, 30 … 75)
    ///
    /// 라벨이 눈금 바깥으로 나가면서 반경이 커졌다. 11pt 그대로 두면 원이 커진 만큼
    /// 상대적으로 작아 보인다.
    public static let dialTick = Font.system(size: 13, weight: .medium, design: .rounded)
}

/// §10 레이아웃 상수.
public enum Metrics {

    /// 카드 모서리 반경
    public static let cardCornerRadius: CGFloat = 16

    /// 카드 테두리 두께
    public static let cardStrokeWidth: CGFloat = 1

    /// 다이얼 바깥으로 드래그를 계속 인정해 주는 여유 반경 (§4.0 제스처 충돌 처리)
    public static let dialHitSlop: CGFloat = 40

    /// 페이지 인디케이터 높이 (§4.0 — 시스템 점 대신 직접 그린다)
    public static let pageIndicatorHeight: CGFloat = 3
}
