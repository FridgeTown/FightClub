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
    @NSManaged public var highlights: [TimeInterval]
    
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
