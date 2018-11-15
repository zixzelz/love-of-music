//
//  ResultSearchTableViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import ReactiveSwift
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

    func viewModel(at indexPath: IndexPath) -> AlbumDetailViewModeling {
        let obj = fetchResult.object(at: indexPath)
        return AlbumDetailViewModel(item: obj.object)
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

class AlternativeResultSearchTableViewModel: AlternativeResultSearchTableViewModeling {

    private struct Constants {
        static let pageSize = 20
    }

    private var albumService: AlbumService
    private let searchText: MutableProperty<String?>

    init() {
        self.albumService = AlbumService()
        self.searchText = MutableProperty(nil)
    }

    lazy var listViewModel: Property<ListViewModel<ResultSearchCellViewModel>> = {
        let property = fetchResult.map { fetchResult -> ListViewModel<ResultSearchCellViewModel> in
            return ListViewModel.model(fetchResult: fetchResult) { item -> ResultSearchCellViewModel in
                return ResultSearchCellViewModel(release: item.object)
            }
        }
        return property
    }()

    lazy var fetchResult: Property<FetchResult<AlbumPageEntity>> = {

        let networkService = albumService.networkService

        let property = searchText.map { searchText -> FetchResult<AlbumPageEntity> in

            guard let searchText = searchText, searchText.count > 0 else {
                return StaticFetchResult(items: [])
            }

            let query = AlbumQuery(queryInfo: .query(text: searchText))

            let context = CoreDataHelper.managedObjectContext
            let predicate = NSPredicate(format: "\(#keyPath(AlbumPageEntity.filterId)) = %@", query.identifier)

            let fetchRequest = NSFetchRequest<AlbumPageEntity>()
            fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: AlbumPageEntity.self), in: context)
            fetchRequest.relationshipKeyPathsForPrefetching = ["\(#keyPath(AlbumPageEntity.object))"]
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "\(#keyPath(AlbumPageEntity.order))", ascending: true)]
            fetchRequest.fetchBatchSize = Constants.pageSize
            fetchRequest.predicate = predicate

            let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

            return CustomFetchResult(fr: frc, pageSize: Constants.pageSize, load: { [weak self] range in
                return networkService.loadNewData(query, cache: .cachedThenLoad, range: range).map { $0.pageInfo }
            })
        }

        return property
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
            self?.searchText.value = text
            if let text = text, text.count > 0 {
                self?.addRecentSearchItem(with: text)
            }
        }
    }

    func viewModel(at indexPath: IndexPath) -> AlbumDetailViewModeling {
        let obj = fetchResult.value.object(at: indexPath)
        return AlbumDetailViewModel(item: obj.object)
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

}
