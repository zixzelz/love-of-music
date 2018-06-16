//
//  SearchHistoryEntity+CoreDataClass.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/16/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SearchHistoryEntity)
public class SearchHistoryEntity: NSManagedObject {

}

extension SearchHistoryEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchHistoryEntity> {
        return NSFetchRequest<SearchHistoryEntity>(entityName: "SearchHistoryEntity")
    }

    @NSManaged public var itemId: String
    @NSManaged public var title: String
    @NSManaged public var date: NSDate
}

extension SearchHistoryEntity: ManagedObjectType {
    public var identifier: String? {
        return itemId
    }

}
