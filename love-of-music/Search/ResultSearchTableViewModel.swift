//
//  ResultSearchTableViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

class ResultSearchTableViewModel: ResultSearchTableViewModeling {

    private struct Constants {
        static let pageSize = 20
    }

    private var albumService: AlbumService

    lazy var listViewModel: ListViewModel<SearchCellViewModel> = {
        let lvm = ListViewModel.model(fetchResult: fetchResult) { (item) -> SearchCellViewModel in
            return SearchCellViewModel(release: item.object)
        }
        return lvm
    }()

    lazy var fetchResult: FetchResult<AlbumPageEntity, AlbumEntity, AlbumPageEntity, AlbumQuery> = {
        let networkService = albumService.networkService
        return FetchResult(networkService: networkService, cachePolicy: .cachedThenLoad, pageSize: Constants.pageSize) { filterId -> NSFetchedResultsController<AlbumPageEntity> in

            let context = CoreDataHelper.managedObjectContext
            let predicate = NSPredicate(format: "\(#keyPath(ReleasesPageEntity.filterId)) = %@", filterId)

            let fetchRequest = NSFetchRequest<AlbumPageEntity>()
            fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: AlbumPageEntity.self), in: context)
            fetchRequest.relationshipKeyPathsForPrefetching = ["\(#keyPath(ReleasesPageEntity.object))"]
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "\(#keyPath(ReleasesPageEntity.order))", ascending: true)]
            fetchRequest.fetchBatchSize = Constants.pageSize
            fetchRequest.predicate = predicate

            return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        }
    }()

    private var token: dispatch_cancelable_closure?
    func search(with text: String?) {

        cancel_delay(token)
        token = delay(0.25) { [weak self] in
            if let text = text, text.count > 0 {
                let query: AlbumQuery? = AlbumQuery(queryInfo: .query(text: text))
                self?.fetchResult.performFetch(query: query)
            } else {
                self?.fetchResult.performFetch(query: nil)
            }
        }

    }

    init() {
        albumService = AlbumService()
    }

}
