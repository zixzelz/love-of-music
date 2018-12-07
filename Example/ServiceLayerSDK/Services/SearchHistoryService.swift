//
//  SearchHistoryService.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/16/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import CoreData

class SearchHistoryService {

    init() {
    }

    func addItem(title: String) {
        let context = CoreDataHelper.managedObjectContext

        context.perform {
            let predicate = NSPredicate(format: "\(#keyPath(SearchHistoryEntity.title)) == %@", title)

            var object = SearchHistoryEntity.objects(withPredicate: predicate, fetchLimit: 1, inContext: context)?.first as? SearchHistoryEntity
            if object == nil {
                
                object = SearchHistoryEntity.insert(inContext: context)
                object?.itemId = UUID().uuidString
                object?.title = title
            }
            object?.date = NSDate()

            CoreDataHelper.saveContext(context)
        }
    }

}
