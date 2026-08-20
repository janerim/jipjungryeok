import SwiftUI

/// §10 타이포그래피. 폰트는 SF Pro(시스템)만 쓴다.
public enum Typography {

    /// 다이얼 하단 남은 시간 큰 숫자
    public static let countdown = Font.system(size: 64, weight: .bold, design: .rounded)

    /// 화면 상단 상태 표시 (`🎯 집중`)
    public static let statusLabel = Font.system(.headline, design: .rounded)

    /// 통계 추이 카드의 값 (`00:35`)
    public static let statValue = Font.system(size: 22, weight: .semibold, design: .rounded)

    /// 통계 추이 카드의 항목명 (`오늘`, `이번 주` …)
    public static let statCaption = Font.system(.caption, design: .rounded)

    /// 다이얼 눈금 숫자 라벨 (0, 5, 10 … 55)
    public static let dialTick = Font.system(size: 11, weight: .medium, design: .rounded)
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
