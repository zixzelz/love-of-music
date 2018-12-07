//
//  SearchViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/16/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import ServiceLayerSDK
import CoreData

class SearchViewModel: SearchViewModeling {

    lazy var listViewModel: ListViewModel<String> = {
        let lvm = ListViewModel.model(fetchResult: fetchResult) { (item) -> String in
            return item.title
        }
        return lvm
    }()

    lazy var fetchResult: FetchResult<SearchHistoryEntity> = {

        let context = CoreDataHelper.managedObjectContext

        let fetchRequest = NSFetchRequest<SearchHistoryEntity>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: SearchHistoryEntity.self), in: context)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "\(#keyPath(SearchHistoryEntity.date))", ascending: false)]
        fetchRequest.fetchLimit = 30

        let fr = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

        return FetchResult<SearchHistoryEntity>.basicResult(fr: fr)
    }()
}
