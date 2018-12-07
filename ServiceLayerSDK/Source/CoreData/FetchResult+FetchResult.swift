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

public extension FetchResult {

    public static func basicResult <FetchObjectType> (fr: NSFetchedResultsController<FetchObjectType>) -> FetchResult<FetchObjectType> where FetchObjectType: NSFetchRequestResult {
        return CustomFetchResult<FetchObjectType>(fr: fr, load: { _ -> SignalProducer<PageInfo?, ServiceError> in
            return SignalProducer({ (observer, _) in
                observer.sendCompleted()
            })
        })
    }

    public static func customResult <FetchObjectType> (fr: NSFetchedResultsController<FetchObjectType>, pageSize: Int? = nil, load: @escaping LoadAction) -> FetchResult<FetchObjectType> where FetchObjectType: NSFetchRequestResult {
        return CustomFetchResult<FetchObjectType>(fr: fr, pageSize: pageSize, load: load)
    }

}

public typealias LoadAction = (_ range: NSRange?) -> SignalProducer<PageInfo?, ServiceError>

public class CustomFetchResult<PageObjectType: NSFetchRequestResult>: FetchResult<PageObjectType>, NSFetchedResultsControllerDelegate {

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
    public override var state: Property<FetchResultState> {
        return stateProperty
    }

    fileprivate var didUpdateObserver: Signal<[UpdateType], NoError>.Observer
    private var didUpdateSignal: Signal<[UpdateType], NoError>
    public override var didUpdate: Signal<[UpdateType], NoError> {
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

    public convenience init(fr: NSFetchedResultsController<PageObjectType>, cachePolicyForFirstLoad: CachePolicy = .cachedThenLoad, pageSize: Int? = nil, load: @escaping LoadAction) {
        self.init(fetchedResults: fr, cachePolicyForFirstLoad: cachePolicyForFirstLoad, pageSize: pageSize, load: load)
    }

    func reload() {
        try? fetchedResultsController?.performFetch()

        totalCount = 0
        performFetch()
    }

    fileprivate func performFetch() {

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

    public override func loadNextPageIfNeeded() {

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

    fileprivate func loadPage(_ page: Int, completion: ((_ numberOfItems: Int) -> Void)? = nil) {
        _state.value = .loading
        print("loadPage \(page)")

        let range = pageSize.map { NSRange(location: page * $0, length: $0) }
        performLoad(range)
            .on(completed: {
                DispatchQueue.main.async { [weak self] in
                    self?._state.value = .loaded
                }
            })
            .startWithResult { [weak self] result in
                print("page \(page) loaded with result: \(result)")
                switch result {
                case .success(let pageInfo):
                    self?.numberOfLoadedPages = page + 1
                    self?.totalCount = pageInfo?.totalCount

                case .failure:
                    self?.totalCount = 0
                }
        }
    }

    fileprivate func performLoad(_ range: NSRange?) -> SignalProducer<PageInfo?, ServiceError> {
        return loadAction(range)
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

    public override func numberOfSections() -> Int {
        return 1
    }

    public override func numberOfRows(inSection section: Int) -> Int {
        guard let sections = fetchedResultsController?.sections, sections.count > section else {
            return 0
        }
        return min(sections[section].numberOfObjects, visibleCount)
    }

    public override func object(at indexPath: IndexPath) -> FetchObjectType {
        guard let fetchedResultsController = fetchedResultsController else {
            fatalError("indexPath out of range")
        }
        return fetchedResultsController.object(at: indexPath)
    }

    public override func indexPathForObject(_ object: FetchObjectType) -> IndexPath? {
        return fetchedResultsController?.indexPath(forObject: object)
    }

    //MARK: NSFetchedResultsControllerDelegate

    fileprivate var changedItems: [UpdateType]?

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("♻️ controllerWillChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count))")
        changedItems = []
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

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

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("✅ controllerDidChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count))")
        performUpdate()
    }

}

public class PageFetchResult <PageObjectType: NSFetchRequestResult, NetworkServiceQuery: NetworkServiceQueryType>: CustomFetchResult<PageObjectType>
where PageObjectType: PageModelType, NetworkServiceQuery.QueryInfo == PageObjectType.ObjectType.QueryInfo {

    private let networkService: NetworkService<PageObjectType.ObjectType>
    private var query: NetworkServiceQuery?

    private var _fetchedResultsController: (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>

    private init(fr: NSFetchedResultsController<PageObjectType>, pageSize: Int? = nil, load: @escaping LoadAction) {
        fatalError("Private")
    }

    public init(networkService service: NetworkService<PageObjectType.ObjectType>, cachePolicy: CachePolicy, pageSize: Int, fetchedResultsController: @escaping (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>) {
        self.networkService = service

        _fetchedResultsController = fetchedResultsController

        super.init(fetchedResults: nil, pageSize: pageSize) { (range) -> SignalProducer<PageInfo?, ServiceError> in
            return SignalProducer.empty
        }
    }

    public func performFetch(query: NetworkServiceQuery?) {
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

        performFetch()
    }

    private func fetchRange(_ range: NSRange) -> SignalProducer<PageInfo?, ServiceError> {
        guard let query = query else {
            return SignalProducer.empty
        }
        return networkService.loadNewData(query, cache: .reloadIgnoringCache, range: range).map { $0.pageInfo }
    }

    override fileprivate func performLoad(_ range: NSRange?) -> SignalProducer<PageInfo?, ServiceError> {
        guard let range = range else {
            fatalError("Unexpected range")
        }

        guard let query = query else {
            return SignalProducer.empty
        }
        return networkService.loadNewData(query, cache: .reloadIgnoringCache, range: range).map { $0.pageInfo }
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

}
