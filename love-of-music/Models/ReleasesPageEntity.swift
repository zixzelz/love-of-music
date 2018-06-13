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

    @NSManaged var filterId: String
    @NSManaged var object: ObjectType
    @NSManaged var order: Int

    required init(filterId: String, object: ReleasesEntity, order: Int, inContext context: ManagedObjectContextType) {
        guard let context = context as? NSManagedObjectContext else {
            fatalError("Unexpected context type")
        }

        let entity = NSEntityDescription.entity(forEntityName: String(describing: ReleasesPageEntity.self), in: context)
        super.init(entity: entity!, insertInto: context)
        self.filterId = filterId
        self.object = object
        self.order = order
    }

    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

    // MARK: - ManagedObjectType

    var identifier: String? {
        return filterId
    }
}
