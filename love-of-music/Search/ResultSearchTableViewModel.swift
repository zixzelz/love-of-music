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
        static let pageSize = 6
    }

    private var releasesService: ReleasesService

    lazy var listViewModel: ListViewModel<SearchCellViewModel> = {
        let lvm = ListViewModel.model(fetchResult: fetchResult) { (item) -> SearchCellViewModel in
            return SearchCellViewModel(release: item.object)
        }
        return lvm
    }()

    lazy var fetchResult: FetchResult<ReleasesPageEntity, ReleasesEntity, ReleasesPageEntity, ReleasesQuery> = {
        let networkService = releasesService.networkService
        return FetchResult(networkService: networkService, cachePolicy: .cachedThenLoad, pageSize: Constants.pageSize) { filterId -> NSFetchedResultsController<ReleasesPageEntity> in

            let context = CoreDataHelper.managedObjectContext
            let predicate = NSPredicate(format: "\(#keyPath(ReleasesPageEntity.filterId)) = %@", filterId)

            let fetchRequest = NSFetchRequest<ReleasesPageEntity>()
            fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: ReleasesPageEntity.self), in: context)
            fetchRequest.relationshipKeyPathsForPrefetching = ["\(#keyPath(ReleasesPageEntity.object))"]
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "\(#keyPath(ReleasesPageEntity.order))", ascending: true)]
            fetchRequest.fetchBatchSize = Constants.pageSize
            fetchRequest.predicate = predicate

            return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        }
    }()

    init() {
        releasesService = ReleasesService()
        setup()
    }

    private func setup() {
        let query = ReleasesQuery()
        fetchResult.performFetch(query: query)
    }

}