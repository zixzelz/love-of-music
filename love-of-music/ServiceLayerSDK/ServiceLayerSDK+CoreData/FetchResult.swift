//
//  FetchResult.swift
//  Music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

enum FetchResultState: Equatable {
    case none, loading, loaded
    public static func == (lhs: FetchResultState, rhs: FetchResultState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.loading, .loading):
            return true
        case (.loaded, .loaded):
            return true
        default:
            return false
        }
    }
}

enum UpdateType {
    case insert(IndexPath), update(IndexPath), delete(IndexPath), move(IndexPath, IndexPath)
}

protocol FetchResultType: class {
    associatedtype FetchObjectType

    var numberOfFetchedObjects: Int { get }
    func object(at indexPath: IndexPath) -> FetchObjectType

    var state: Property<FetchResultState> { get }
    var didUpdate: Property<[UpdateType]> { get }

    func loadNextPageIfNeeded()
}

class FetchResult <FetchObjectType: NSFetchRequestResult, ObjectType, PageObjectType: PageModelType, NetworkServiceQuery: NetworkServiceQueryType>: NSObject, FetchResultType, NSFetchedResultsControllerDelegate where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {

    private let networkService: NetworkService<ObjectType, PageObjectType>
    private var query: NetworkServiceQuery?
    private let cachePolicy: CachePolicy
    private let pageSize: Int?
    private var numberOfLoadedPages: Int
    private var totalCount: Int

    private var _fetchedResultsController: (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>
    private var fetchedResultsController: NSFetchedResultsController<FetchObjectType>?

    private var _state: MutableProperty<FetchResultState>
    lazy var state: Property<FetchResultState> = {
        return Property(_state)
    }()

    private var _didUpdate: MutableProperty<[UpdateType]>
    lazy var didUpdate: Property<[UpdateType]> = {
        return Property(_didUpdate)
    }()

    init(networkService service: NetworkService<ObjectType, PageObjectType>, cachePolicy: CachePolicy, pageSize: Int? = nil, fetchedResultsController: @escaping (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>) { //} where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {

        self.networkService = service
        self.cachePolicy = cachePolicy
        self.pageSize = pageSize
        self.numberOfLoadedPages = 0
        self.totalCount = 0

        _state = MutableProperty(value: .none)
        _didUpdate = MutableProperty(value: [])
        _fetchedResultsController = fetchedResultsController//FetchResult.makeFetchedResultsController(pageSize: pageSize)

        super.init()
    }

    func performFetch(query: NetworkServiceQuery?) {
        self.query = query

        guard let query = query else {
            fetchedResultsController = nil
            numberOfLoadedPages = 0
            totalCount = 0
            _state.value = .none
            return
        }

        let filterId = query.filterIdentifier
        fetchedResultsController = _fetchedResultsController(filterId)
        fetchedResultsController?.delegate = self
        try? fetchedResultsController?.performFetch()

        print("✅new fetchedResultsController: \(String(describing: fetchedResultsController?.fetchedObjects?.count))")

        numberOfLoadedPages = 1
        totalCount = 0

        _state.value = .loaded
        _didUpdate.value = []

        changedItems = []

        loadPage(0)
    }

    private func loadPage(_ page: Int, completion: ((_ numberOfItems: Int) -> Void)? = nil) {
        _state.value = .loading
        fetchPage(page) { [weak self] numberOfItems in
            guard let strongSelf = self else {
                return
            }

            self?.totalCount = numberOfItems

            DispatchQueue.main.async {
                self?._state.value = .loaded
                if let changedItems = strongSelf.changedItems {
                    strongSelf._didUpdate.value = changedItems
                }
            }

            completion?(numberOfItems)
        }
    }

    private func fetchPage(_ page: Int, completion: @escaping (_ numberOfItems: Int) -> Void) {

        guard let query = query else {
            return
        }

        let range = pageSize.map { NSRange(location: page * $0, length: $0) }

        let oldFilterIdentifier = query.filterIdentifier
        networkService.fetchPageData(query, cache: cachePolicy, range: range) { [weak self] (result) in
            guard let currentQuery = self?.query, oldFilterIdentifier == currentQuery.filterIdentifier else {
                print("❌ fetchPageData for old query")
                return
            }
            guard case .success(let info) = result else {
                print("error: \(result)")
                return
            }
            print("result: \(info.totalItems)")
            completion(info.totalItems)
        }

    }

//    private func updateFetchedResultsController(filterId: String) {
//        let predicate = NSPredicate(format: "filterId = %@", filterId) //#keyPath(ReleasesPageEntity.filterId)
//        fetchedResultsController.fetchRequest.predicate = predicate
//        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: nil)
//        try? fetchedResultsController.performFetch()
//    }

    //MARK: NSFetchedResultsControllerDelegate

    var numberOfFetchedObjects: Int {
        let count = fetchedResultsController?.fetchedObjects?.count ?? 0
        let limitCount = pageSize.map { min(count, $0 * numberOfLoadedPages) }
        return limitCount ?? count
    }

    func object(at indexPath: IndexPath) -> FetchObjectType {
        guard let fetchedResultsController = fetchedResultsController else {
            fatalError("indexPath out of range")
        }
        return fetchedResultsController.object(at: indexPath)
    }

    private var loadingPage: Bool = false
    func loadNextPageIfNeeded() {

        guard _state.value != .loading, totalCount > numberOfFetchedObjects else {
            print("loadPage canceled")
            return
        }

        loadingPage = true

        let page = numberOfLoadedPages
        loadPage(page) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            strongSelf.numberOfLoadedPages += 1
            strongSelf.loadingPage = false
            print("loadPage finished pages: \(strongSelf.numberOfLoadedPages)")
        }
    }

    //MARK: NSFetchedResultsControllerDelegate

    private var changedItems: [UpdateType]?

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("♻️ controllerWillChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count)), \(numberOfFetchedObjects)")
        changedItems = []
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let newIndexPath = newIndexPath {
            switch type {
            case .insert:
                changedItems?.append(.insert(newIndexPath))
            case .delete:
                changedItems?.append(.delete(newIndexPath))
            case .update:
                changedItems?.append(.update(newIndexPath))
            case .move:
                if let indexPath = indexPath {
                    changedItems?.append(.move(indexPath, newIndexPath))
                }
            }
            print("didChange \(newIndexPath) \(type.rawValue)")
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("✅ controllerDidChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count)), \(numberOfFetchedObjects)")
    }

}

//extension FetchResult where FetchObjectType == PageModelType {
//
//}

//class PageFetchResult <ObjectType, PageObjectType: PageModelType & NSFetchRequestResult, NetworkServiceQuery: NetworkServiceQueryType>: FetchResult<ObjectType, PageObjectType, NetworkServiceQuery> where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {
//
//    init(networkService service: NetworkService<ObjectType, PageObjectType>, cachePolicy: CachePolicy, pageSize: Int) {
//        super.init(networkService: service, cachePolicy: cachePolicy, pageSize: pageSize) { () -> NSFetchedResultsController<FetchObjectType> in
//
//            let context = CoreDataHelper.managedObjectContext
//
//            let fetchRequest = NSFetchRequest<FetchObjectType>()
//            fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: FetchObjectType.self), in: context)
//            fetchRequest.relationshipKeyPathsForPrefetching = ["object"] //#keyPath(PageModelType.object)
//            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)] //#keyPath(PageObjectType.order)
//            fetchRequest.fetchBatchSize = pageSize
//
//            return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
//        }
//    }
//
//}

//private extension FetchResult {
//
//    private static func makeFetchedResultsController(pageSize: Int?) -> NSFetchedResultsController<FetchObjectType> {
//        let context = CoreDataHelper.managedObjectContext
//
//        let fetchRequest = NSFetchRequest<FetchObjectType>()
//        fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: FetchObjectType.self), in: context)
//        fetchRequest.relationshipKeyPathsForPrefetching = ["object"] //#keyPath(PageModelType.object)
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)] //#keyPath(PageObjectType.order)
//
//        if let pageSize = pageSize {
//            fetchRequest.fetchBatchSize = pageSize
//        }
//
//        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
//    }
//}
