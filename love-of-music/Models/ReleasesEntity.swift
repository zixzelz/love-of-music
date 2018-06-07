//
//  ReleasesEntity.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

@objc(ReleasesEntity)
class ReleasesEntity: NSManagedObject {

    @NSManaged var title: String?
    @NSManaged var userId: String
}

extension ReleasesEntity: ModelType {

    typealias QueryInfo = OjectQueryInfo

    static func identifier(_ json: [String: AnyObject]) -> String? {
        let id = json["id"] as? Int
        return id.map { String($0) }
    }

    static func objects(_ json: [String: AnyObject]) -> [[String: AnyObject]]? {

        return json["releases"] as? [[String: AnyObject]]
    }

    func fill(_ json: [String: AnyObject], queryInfo: QueryInfo, context: Void) {
        userId = ReleasesEntity.identifier(json)!
        update(json, queryInfo: queryInfo)
    }

    func update(_ json: [String: AnyObject], queryInfo: QueryInfo) {
        title = json["title"] as? String
    }

    // MARK: - ManagedObjectType

    var identifier: String? {
        return userId
    }

}
