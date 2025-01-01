//
//  BoxingSession.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import Foundation
import CoreData

class BoxingSession: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var duration: Double
    @NSManaged public var punchCount: Int32
    @NSManaged public var memo: String?
    @NSManaged public var videoURL: URL?
    @NSManaged public var highlightsData: Data?
    
    // 배열을 가져오고 설정하기 위한 계산 프로퍼티
    var highlights: [TimeInterval] {
        get {
            if let data = highlightsData {
                return (try? JSONDecoder().decode([TimeInterval].self, from: data)) ?? []
            }
            return []
        }
        set {
            highlightsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // 생성 시 자동으로 ID 할당
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        date = Date()
    }
}

extension BoxingSession {
    static func fetchRequest() -> NSFetchRequest<BoxingSession> {
        return NSFetchRequest<BoxingSession>(entityName: "BoxingSession")
    }
}
