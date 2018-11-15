//
//  ViewControllerViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/11/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ReactiveSwift
import CoreData

class ViewControllerViewModel: ViewControllerViewModeling {

    private struct Constants {
        static let pageSize = 6
    }

    private var releasesService: ReleasesService

    lazy var listViewModel: ListViewModel<ReleasesCellViewModel> = {
        let lvm = ListViewModel.model(fetchResult: fetchResult) { (item) -> ReleasesCellViewModel in
            return ReleasesCellViewModel(release: item.object)
        }
        return lvm
    }()

    lazy var fetchResult: PageFetchResult<ReleasesPageEntity, ReleasesQuery> = {
        let networkService = releasesService.networkService
        return PageFetchResult(networkService: networkService, cachePolicy: .cachedThenLoad, pageSize: Constants.pageSize) { filterId -> NSFetchedResultsController<ReleasesPageEntity> in

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

class AlternativeViewControllerViewModel: ViewControllerViewModeling {

    private struct Constants {
        static let pageSize = 6
    }

    private var releasesService: ReleasesService

    lazy var listViewModel: ListViewModel<ReleasesCellViewModel> = {
        let lvm = ListViewModel.model(fetchResult: fetchResult) { (item) -> ReleasesCellViewModel in
            return ReleasesCellViewModel(release: item.object)
        }
        return lvm
    }()

    lazy var fetchResult: CustomFetchResult<ReleasesPageEntity> = {

        let networkService = releasesService.networkService
        let query = ReleasesQuery()

        let context = CoreDataHelper.managedObjectContext
        let predicate = NSPredicate(format: "\(#keyPath(ReleasesPageEntity.filterId)) = %@", query.identifier)

        let fetchRequest = NSFetchRequest<ReleasesPageEntity>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: ReleasesPageEntity.self), in: context)
        fetchRequest.relationshipKeyPathsForPrefetching = ["\(#keyPath(ReleasesPageEntity.object))"]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "\(#keyPath(ReleasesPageEntity.order))", ascending: true)]
        fetchRequest.fetchBatchSize = Constants.pageSize
        fetchRequest.predicate = predicate

        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

        return CustomFetchResult(fr: frc, pageSize: Constants.pageSize, load: { [weak self] range in
            return networkService.loadNewData(query, cache: .cachedThenLoad, range: range).map { $0.pageInfo }
        })
    }()

    init() {
        releasesService = ReleasesService()
        setup()
    }

    private func setup() {

    }

}
