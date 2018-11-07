//
//  FetchResult.swift
//  Music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import CoreData

class FetchResult <FetchObjectType: NSFetchRequestResult>: NSObject, FetchResultType, NSFetchedResultsControllerDelegate {

    fileprivate var fetchedResultsController: NSFetchedResultsController<FetchObjectType>?

    fileprivate var _state: MutableProperty<FetchResultState>
    lazy var state: Property<FetchResultState> = {
        return Property(_state)
    }()

    var didUpdate: Signal<[UpdateType], NoError>
    fileprivate var didUpdateObserver: Signal<[UpdateType], NoError>.Observer

    fileprivate override init() {
        _state = MutableProperty(.none)
        (didUpdate, didUpdateObserver) = Signal<[UpdateType], NoError>.pipe()
        super.init()
    }

    func numberOfSections() -> Int {
        return 1
    }

    func numberOfRows(inSection section: Int) -> Int {
        let count = fetchedResultsController?.fetchedObjects?.count ?? 0
        return count
    }

    func object(at indexPath: IndexPath) -> FetchObjectType {
        guard let fetchedResultsController = fetchedResultsController else {
            fatalError("indexPath out of range")
        }
        return fetchedResultsController.object(at: indexPath)
    }

    func indexPathForObject(_ object: FetchObjectType) -> IndexPath? {
        return fetchedResultsController?.indexPath(forObject: object)
    }

    func loadNextPageIfNeeded() {
        preconditionFailure("Should be overriden")
    }

//MARK: NSFetchedResultsControllerDelegate

    fileprivate var changedItems: [UpdateType]?

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("♻️ controllerWillChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count))")
        changedItems = []
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            changedItems?.append(.insert(newIndexPath!))
        case .delete:
            changedItems?.append(.delete(indexPath!))
        case .update:
            changedItems?.append(.update(indexPath!))
        case .move:
            changedItems?.append(.move(indexPath!, newIndexPath!))
        }
        print("didChange [\(String(describing: indexPath)) \(String(describing: newIndexPath))] \(type.rawValue)")
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("✅ controllerDidChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count))")
    }

}

extension FetchResult {

    static func basicResult (
        fetchedResultsController: @escaping () -> NSFetchedResultsController<FetchObjectType>
    ) -> FetchResult<FetchObjectType> {

        return BasicFetchResult<FetchObjectType>(
            fetchedResultsController: fetchedResultsController
        )
    }

}

//extension FetchResult {
//
//    static func pageResult <PageObjectType: NSFetchRequestResult> (
//        networkService service: NetworkService<PageObjectType.ObjectType>,
////        query: Query?, //Workaround, because I can't specify generic parameter with not used in function signature
//        cachePolicy: CachePolicy,
//        pageSize: Int? = nil,
//        fetchedResultsController: @escaping (_ filterId: String) -> NSFetchedResultsController<PageObjectType>
//    ) -> FetchResult<PageObjectType> where PageObjectType: PageModelType {
//
//        return PageFetchResult<PageObjectType>(
//            networkService: service,
//            cachePolicy: cachePolicy,
//            fetchedResultsController: fetchedResultsController
//        )
//    }
//}
//, Query.QueryInfo == PageObjectType.ObjectType.QueryInfo
// TODO: make it private
class PageFetchResult <PageObjectType: NSFetchRequestResult, NetworkServiceQuery: NetworkServiceQueryType>: FetchResult<PageObjectType>
where PageObjectType: PageModelType, NetworkServiceQuery.QueryInfo == PageObjectType.ObjectType.QueryInfo {

//    typealias NetworkServiceQuery = NetworkServiceQueryType where Query.QueryInfo == PageObjectType.ObjectType.QueryInfo

    private let networkService: NetworkService<PageObjectType.ObjectType>
    private var query: NetworkServiceQuery?
    private let cachePolicy: CachePolicy
    private let pageSize: Int?
    private var numberOfLoadedPages: Int
    private var totalCount: Int

    private var _fetchedResultsController: (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>

    init(networkService service: NetworkService<PageObjectType.ObjectType>, cachePolicy: CachePolicy, pageSize: Int? = nil, fetchedResultsController: @escaping (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>) {

        self.networkService = service
        self.cachePolicy = cachePolicy
        self.pageSize = pageSize
        self.numberOfLoadedPages = 0
        self.totalCount = 0

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
            didUpdateObserver.send(value: [])
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
        didUpdateObserver.send(value: [])

        changedItems = []

        loadPage(0)
    }

    private func loadPage(_ page: Int, completion: ((_ numberOfItems: Int) -> Void)? = nil) {
        _state.value = .loading
        print("loadPage \(page)")
        fetchPage(page) { [weak self] numberOfItems in

            self?.totalCount = numberOfItems

            DispatchQueue.main.async {
                self?._state.value = .loaded
                self?.performUpdate()
            }

            completion?(numberOfItems)
        }
    }

    private func performUpdate() {
        if let changedItems = changedItems {

            let count = numberOfRows(inSection: 0)
            let filteredList = changedItems.filter { update -> Bool in
                switch update {
                case
                     .insert(let indexPath),
                     .update(let indexPath),
                     .delete(let indexPath):
                    return indexPath.row < count
                case .move(let atIndexPath, let toIndexPath):
                    return atIndexPath.row < count && toIndexPath.row < count
                }
            }

            didUpdateObserver.send(value: filteredList)
        }
    }

    private func fetchPage(_ page: Int, completion: @escaping (_ numberOfItems: Int) -> Void) {

        guard let query = query else {
            return
        }

        let range = pageSize.map { NSRange(location: page * $0, length: $0) }

        let oldFilterIdentifier = query.filterIdentifier
        networkService.loadData(query, range: range) { [weak self] (result) in
            guard let currentQuery = self?.query, oldFilterIdentifier == currentQuery.filterIdentifier else {
                print("❌ fetchPageData for old query")
                return
            }
            guard case .success(let info) = result else {
                print("error: \(result)")
                return
            }
            print("fetchPage: \(page) result: \(info.totalItems)")
            completion(info.totalItems)
        }

    }

    override func loadNextPageIfNeeded() {

        let numberOfFetchedObjects = numberOfRows(inSection: 0)
        guard _state.value != .loading, totalCount > numberOfFetchedObjects else {
            print("loadPage canceled")
            return
        }

        let page = numberOfLoadedPages
        loadPage(page) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            strongSelf.numberOfLoadedPages += 1
            print("loadPage finished pages: \(strongSelf.numberOfLoadedPages)")
        }
    }

    override func numberOfRows(inSection section: Int) -> Int {
        let count = fetchedResultsController?.fetchedObjects?.count ?? 0
        let limitCount = pageSize.map { min(count, $0 * numberOfLoadedPages) }
        return limitCount ?? count
    }

}

private class BasicFetchResult <FetchObjectType: NSFetchRequestResult>: FetchResult<FetchObjectType> {

    private var _fetchedResultsController: () -> NSFetchedResultsController<FetchObjectType>

    init(fetchedResultsController: @escaping () -> NSFetchedResultsController<FetchObjectType>) {
        _fetchedResultsController = fetchedResultsController

        super.init()

        DispatchQueue.main.async {
            self.setup()
        }
    }

    private func setup() {

        fetchedResultsController = _fetchedResultsController()
        fetchedResultsController?.delegate = self

        do {
            try fetchedResultsController?.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }

        print("✅new fetchedResultsController: \(String(describing: fetchedResultsController?.fetchedObjects?.count))")

        _state.value = .loaded
        didUpdateObserver.send(value: [])

        changedItems = []
    }

    override func loadNextPageIfNeeded() {
    }

    //MARK: NSFetchedResultsControllerDelegate

    override func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("✅ controllerDidChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count))")

        if let changedItems = changedItems {
            didUpdateObserver.send(value: changedItems)
        }
    }

}
