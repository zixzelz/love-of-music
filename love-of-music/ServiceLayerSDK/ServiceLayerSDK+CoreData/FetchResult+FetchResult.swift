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

extension FetchResult {

    static func basicResult <FetchObjectType> (fr: NSFetchedResultsController<FetchObjectType>) -> FetchResult<FetchObjectType> where FetchObjectType: NSFetchRequestResult {
        return CustomFetchResult<FetchObjectType>(fr: fr, load: { _ -> SignalProducer<PageInfo?, ServiceError> in
            return SignalProducer.empty
        })
    }

    static func customResult <FetchObjectType> (fr: NSFetchedResultsController<FetchObjectType>, pageSize: Int? = nil, load: @escaping CustomFetchResult<FetchObjectType>.LoadAction) -> FetchResult<FetchObjectType> where FetchObjectType: NSFetchRequestResult {
        return CustomFetchResult<FetchObjectType>(fr: fr, pageSize: pageSize, load: load)
    }

}

class CustomFetchResult<PageObjectType: NSFetchRequestResult>: FetchResult<PageObjectType>, NSFetchedResultsControllerDelegate {

    typealias LoadAction = (_ range: NSRange?) -> SignalProducer<PageInfo?, ServiceError>

    fileprivate let cachePolicy: CachePolicy
    fileprivate let pageSize: Int?
    fileprivate var numberOfLoadedPages: Int
    fileprivate var totalCount: Int?
    private let loadAction: LoadAction

    fileprivate var fetchedResultsController: NSFetchedResultsController<FetchObjectType>?

    fileprivate var _state: MutableProperty<FetchResultState>
    private lazy var stateProperty: Property<FetchResultState> = {
        return Property(_state)
    }()
    override var state: Property<FetchResultState> {
        return stateProperty
    }

    fileprivate var didUpdateObserver: Signal<[UpdateType], NoError>.Observer
    private var didUpdateSignal: Signal<[UpdateType], NoError>
    override var didUpdate: Signal<[UpdateType], NoError> {
        return didUpdateSignal
    }

    fileprivate init(fetchedResults: NSFetchedResultsController<PageObjectType>?, cachePolicyForFirstLoad: CachePolicy = .cachedThenLoad, pageSize: Int? = nil, load: @escaping LoadAction) {
        _state = MutableProperty(.none)
        (didUpdateSignal, didUpdateObserver) = Signal<[UpdateType], NoError>.pipe()

        self.cachePolicy = cachePolicyForFirstLoad
        self.pageSize = pageSize
        self.loadAction = load
        self.numberOfLoadedPages = 0
        self.totalCount = 0

        super.init()

        self.fetchedResultsController = fetchedResults
        fetchedResults?.delegate = self

        reload()
    }

    convenience init(fr: NSFetchedResultsController<PageObjectType>, cachePolicyForFirstLoad: CachePolicy = .cachedThenLoad, pageSize: Int? = nil, load: @escaping LoadAction) {
        self.init(fetchedResults: fr, cachePolicyForFirstLoad: cachePolicyForFirstLoad, pageSize: pageSize, load: load)
    }

    func reload() {
        try? fetchedResultsController?.performFetch()

        totalCount = 0
        performFetch()
    }

    private func performFetch() {

        numberOfLoadedPages = 1
        totalCount = 0

        changedItems = []

        switch cachePolicy {
        case .cachedOnly:
            didUpdateObserver.send(value: [])
        case .cachedThenLoad:
            didUpdateObserver.send(value: [])
            loadPage(0)
        case .cachedElseLoad:
            if let count = fetchedResultsController?.fetchedObjects?.count, count > 0 {
                didUpdateObserver.send(value: [])
            } else {
                loadPage(0)
            }
        case .reloadIgnoringCache:
            loadPage(0)
        }
    }

    override func loadNextPageIfNeeded() {

        let numberOfFetchedObjects = visibleCount
        guard _state.value != .loading, let totalCount = totalCount, totalCount > numberOfFetchedObjects else {
            print("loadPage canceled")
            return
        }

        let page = numberOfLoadedPages
        loadPage(page) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            print("loadPage finished pages: \(strongSelf.numberOfLoadedPages)")
        }
    }

    private func loadPage(_ page: Int, completion: ((_ numberOfItems: Int) -> Void)? = nil) {
        _state.value = .loading
        print("loadPage \(page)")

        let range = pageSize.map { NSRange(location: page * $0, length: $0) }
        loadAction(range).startWithResult { [weak self] result in
            switch result {
            case .success(let pageInfo):
                self?.numberOfLoadedPages = page + 1
                self?.totalCount = pageInfo?.totalCount

            case .failure:
                self?.totalCount = 0
            }
            DispatchQueue.main.async {
                self?._state.value = .loaded
                self?.performUpdate()
            }
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

    fileprivate var visibleCount: Int {
        let count = fetchedResultsController?.fetchedObjects?.count ?? 0
        let limitCount = pageSize.map { min(count, $0 * numberOfLoadedPages) }
        return limitCount ?? count
    }

    override func numberOfSections() -> Int {
        return 1
    }

    override func numberOfRows(inSection section: Int) -> Int {
        return visibleCount
    }

    override func object(at indexPath: IndexPath) -> FetchObjectType {
        guard let fetchedResultsController = fetchedResultsController else {
            fatalError("indexPath out of range")
        }
        return fetchedResultsController.object(at: indexPath)
    }

    override func indexPathForObject(_ object: FetchObjectType) -> IndexPath? {
        return fetchedResultsController?.indexPath(forObject: object)
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

class PageFetchResult <PageObjectType: NSFetchRequestResult, NetworkServiceQuery: NetworkServiceQueryType>: CustomFetchResult<PageObjectType>
where PageObjectType: PageModelType, NetworkServiceQuery.QueryInfo == PageObjectType.ObjectType.QueryInfo {

    private let networkService: NetworkService<PageObjectType.ObjectType>
    private var query: NetworkServiceQuery?

    private var _fetchedResultsController: (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>

    private init(fr: NSFetchedResultsController<PageObjectType>, pageSize: Int? = nil, load: @escaping LoadAction) {
        fatalError("Private")
    }

    init(networkService service: NetworkService<PageObjectType.ObjectType>, cachePolicy: CachePolicy, pageSize: Int? = nil, fetchedResultsController: @escaping (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>) {

        self.networkService = service

        _fetchedResultsController = fetchedResultsController//FetchResult.makeFetchedResultsController(pageSize: pageSize)

        super.init(fetchedResults: nil, pageSize: pageSize) { (range) -> SignalProducer<PageInfo?, ServiceError> in
            return SignalProducer.empty
        }
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
