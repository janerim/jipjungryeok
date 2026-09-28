import Foundation
import CoreData
import FocusCore

/// §5 저장되는 세션 1건.
///
/// Core Data 에 묶인 클래스라 `FocusCore` 가 아니라 앱 타깃에 둔다.
/// 엔진과 통계 계산은 이걸 모르고, 값 타입인 `SessionRecord` 만 주고받는다.
///
/// `main` 은 SwiftData(`@Model`)를 쓴다. `ios15` 브랜치는 SwiftData 가 iOS 17 부터라
/// Core Data 로 내려왔다. 필드 구성은 `main` 과 같게 유지한다.
///
/// 모델을 `.xcdatamodeld` 파일이 아니라 코드(`model`)로 정의한다. 필드가 이 파일 하나에
/// 모여 있어야 `@NSManaged` 선언과 모델 정의가 어긋나는 것을 한눈에 잡을 수 있다.
@objc(FocusSession)
final class FocusSession: NSManagedObject {

    @NSManaged var id: UUID

    /// 세션 시작 절대시각. **모든 통계의 날짜 판정 기준이다** (§4.2).
    @NSManaged var startAt: Date

    /// 종료(완료 또는 중지) 절대시각
    @NSManaged var endAt: Date

    @NSManaged var plannedSeconds: Int

    /// 실제 집중한 시간. 일시정지 구간은 빠져 있다.
    @NSManaged var actualSeconds: Int

    /// 끝까지 갔으면 `true`, 중도 중지면 `false`
    @NSManaged var isCompleted: Bool

    /// EventKit 이벤트 식별자. 캘린더 기록(§7, M4)이 성공해야 채워진다.
    @NSManaged var calendarEventID: String?

    /// 세션 직후 남긴 한 줄 메모. 건너뛰면 nil.
    @NSManaged var memo: String?

    convenience init(record: SessionRecord, context: NSManagedObjectContext) {
        // `init(context:)` 는 클래스 이름으로 엔티티를 찾는데, 모델을 코드로 만든 경우
        // 그 조회가 실패하거나 모호해질 수 있다. 엔티티를 직접 넘긴다.
        self.init(entity: Self.sessionEntity, insertInto: context)
        self.id = record.id
        self.startAt = record.startAt
        self.endAt = record.endAt
        self.plannedSeconds = record.plannedSeconds
        self.actualSeconds = record.actualSeconds
        self.isCompleted = record.isCompleted
        self.calendarEventID = nil
        self.memo = record.memo
    }

    var record: SessionRecord {
        SessionRecord(
            id: id,
            startAt: startAt,
            endAt: endAt,
            plannedSeconds: plannedSeconds,
            actualSeconds: actualSeconds,
            isCompleted: isCompleted,
            memo: memo
        )
    }

    /// 같은 `id` 의 세션을 덮어쓴다.
    /// 워치에서 올라온 세션을 upsert 할 때도 이 경로를 쓴다 (§8-1-4).
    func apply(_ record: SessionRecord) {
        startAt = record.startAt
        endAt = record.endAt
        plannedSeconds = record.plannedSeconds
        actualSeconds = record.actualSeconds
        isCompleted = record.isCompleted
        // 메모는 덮어쓰지 않는다. 세션이 끝난 뒤에 따로 붙는 값이라,
        // 엔진이 만든 record 에는 언제나 nil 이다.
    }

    // MARK: - 모델 정의

    static let entityName = "FocusSession"

    static func request() -> NSFetchRequest<FocusSession> {
        NSFetchRequest<FocusSession>(entityName: entityName)
    }

    /// **프로세스에 하나만 있어야 한다.** 컨테이너마다 모델을 새로 만들면 같은 클래스를
    /// 여러 엔티티가 주장하게 되어 Core Data 가 경고를 내고 어느 쪽을 쓸지 헷갈린다
    /// (프리뷰처럼 인메모리 스토어를 따로 여는 경우).
    static let model: NSManagedObjectModel = {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(FocusSession.self)
        entity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("startAt", .dateAttributeType),
            attribute("endAt", .dateAttributeType),
            attribute("plannedSeconds", .integer64AttributeType),
            attribute("actualSeconds", .integer64AttributeType),
            attribute("isCompleted", .booleanAttributeType),
            attribute("calendarEventID", .stringAttributeType, optional: true),
            attribute("memo", .stringAttributeType, optional: true)
        ]
        // `main` 의 `@Attribute(.unique)` 에 해당한다. 평소에는 `SessionStore.save` 가
        // 먼저 찾아보고 덮어쓰므로 걸릴 일이 없고, 그걸 빠져나간 경우의 안전장치다.
        entity.uniquenessConstraints = [["id"]]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }()

    /// `NSManagedObject.entity()` 와 이름이 겹치지 않게 따로 이름을 붙인다.
    private static var sessionEntity: NSEntityDescription {
        // 위 `model` 에서 이 이름으로 넣었으므로 없을 수 없다.
        model.entitiesByName[entityName]!
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
