//
//  ReleasesPageEntity.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/6/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

@objc(ReleasesPageEntity)
class ReleasesPageEntity: NSManagedObject, PageModelType {
    typealias ObjectType = ReleasesEntity

    @NSManaged var pageId: String
    @NSManaged var object: ReleasesEntity
    @NSManaged var order: Int

    required init(pageId: String, object: ReleasesEntity, order: Int, inContext context: ManagedObjectContextType) {
        guard let context = context as? NSManagedObjectContext else {
            fatalError("Unexpected conett type")
        }

        let entity = NSEntityDescription.entity(forEntityName: String(describing: ReleasesPageEntity.self), in: context)
        super.init(entity: entity!, insertInto: context)
        self.pageId = pageId
        self.object = object
        self.order = order
    }

    // MARK: - ManagedObjectType

    var identifier: String? {
        return pageId
    }
}
