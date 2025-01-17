//
//  BoxingSession.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import Foundation
import CoreData

@objc(BoxingSession)
public class BoxingSession: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BoxingSession> {
        return NSFetchRequest<BoxingSession>(entityName: "BoxingSession")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var duration: Double
    @NSManaged public var punchCount: Int32
    @NSManaged public var memo: String?
    @NSManaged public var videoURL: URL?
    @NSManaged public var highlightsData: Data?
    @NSManaged public var heartRate: Double
    @NSManaged public var activeCalories: Double
    @NSManaged public var maxPunchSpeed: Double
    @NSManaged public var avgPunchSpeed: Double
    
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

// MARK: - Identifiable
extension BoxingSession: Identifiable { }
