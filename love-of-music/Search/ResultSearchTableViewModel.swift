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

    lazy var listViewModel: ListViewModel<ResultSearchCellViewModel> = {
        let lvm = ListViewModel.model(fetchResult: fetchResult) { (item) -> ResultSearchCellViewModel in
            return ResultSearchCellViewModel(release: item.object)
        }
        return lvm
    }()

    lazy var fetchResult: PageFetchResult<AlbumPageEntity, AlbumQuery> = {
        let networkService = albumService.networkService

        return PageFetchResult(
            networkService: networkService,
            cachePolicy: .cachedThenLoad,
            pageSize: Constants.pageSize
        ) { (filterId) -> NSFetchedResultsController<AlbumPageEntity> in

            let context = CoreDataHelper.managedObjectContext
            let predicate = NSPredicate(format: "\(#keyPath(AlbumPageEntity.filterId)) = %@", filterId)

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
    private var previouseSearchtText: String?
    func search(with text: String?) {
        guard previouseSearchtText != text else {
            return
        }
        previouseSearchtText = text

        cancel_delay(token)
        token = delay(0.25) { [weak self] in
            if let text = text, text.count > 0 {
                let query: AlbumQuery? = AlbumQuery(queryInfo: .query(text: text))
                self?.fetchResult.performFetch(query: query)
                self?.addRecentSearchItem(with: text)
            } else {
                self?.fetchResult.performFetch(query: nil)
            }
        }

    }

    private var recentSearchItemToken: dispatch_cancelable_closure?
    private func addRecentSearchItem(with text: String) {
        // solution just for imagine
        cancel_delay(recentSearchItemToken)
        recentSearchItemToken = delay(2) {
            print("added SearchHistory item \(text)")
            SearchHistoryService().addItem(title: text)
        }
    }

    init() {
        albumService = AlbumService()
    }

}
