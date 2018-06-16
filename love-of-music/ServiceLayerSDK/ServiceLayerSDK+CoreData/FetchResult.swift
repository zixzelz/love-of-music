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

class FetchResult <FetchObjectType: NSFetchRequestResult>: NSObject, FetchResultType, NSFetchedResultsControllerDelegate {

    fileprivate var fetchedResultsController: NSFetchedResultsController<FetchObjectType>?

    fileprivate var _state: MutableProperty<FetchResultState>
    lazy var state: Property<FetchResultState> = {
        return Property(_state)
    }()

    fileprivate var _didUpdate: MutableProperty<[UpdateType]>
    lazy var didUpdate: Property<[UpdateType]> = {
        return Property(_didUpdate)
    }()

    fileprivate override init() {
        _state = MutableProperty(value: .none)
        _didUpdate = MutableProperty(value: [])
        super.init()
    }

    //MARK: NSFetchedResultsControllerDelegate

    var numberOfFetchedObjects: Int {
        let count = fetchedResultsController?.fetchedObjects?.count ?? 0
        return count
    }

    func object(at indexPath: IndexPath) -> FetchObjectType {
        guard let fetchedResultsController = fetchedResultsController else {
            fatalError("indexPath out of range")
        }
        return fetchedResultsController.object(at: indexPath)
    }

    func loadNextPageIfNeeded() {
        preconditionFailure("Should be overriden")
    }

    //MARK: NSFetchedResultsControllerDelegate

    fileprivate var changedItems: [UpdateType]?

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("♻️ controllerWillChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count)), \(numberOfFetchedObjects)")
        changedItems = []
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            if let newIndexPath = newIndexPath, newIndexPath.row < numberOfFetchedObjects {
                changedItems?.append(.insert(newIndexPath))
            }
        case .delete:
            if let indexPath = indexPath, indexPath.row < numberOfFetchedObjects {
                changedItems?.append(.delete(indexPath))
            }
        case .update:
            if let indexPath = indexPath, indexPath.row < numberOfFetchedObjects {
                changedItems?.append(.update(indexPath))
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath, indexPath.row < numberOfFetchedObjects, newIndexPath.row < numberOfFetchedObjects {
//                changedItems?.append(.move(indexPath, newIndexPath))
                changedItems?.append(.delete(indexPath))
                changedItems?.append(.insert(newIndexPath))
            }
        }
        print("didChange [\(indexPath) \(newIndexPath)] \(type.rawValue)")
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("✅ controllerDidChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count)), \(numberOfFetchedObjects)")
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

extension FetchResult {

    static func pageResult <Query: NetworkServiceQueryType> (
        networkService service: NetworkService<FetchObjectType.ObjectType, FetchObjectType>,
        query: Query?, //Workaround, because I can't specify generic parameter with not used in function signature
        cachePolicy: CachePolicy,
        pageSize: Int? = nil,
        fetchedResultsController: @escaping (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>
    ) -> FetchResult<FetchObjectType> where Query.QueryInfo == FetchObjectType.ObjectType.QueryInfo, FetchObjectType: PageModelType {

        return PageFetchResult<FetchObjectType, Query>(
            networkService: service,
            cachePolicy: cachePolicy,
            fetchedResultsController: fetchedResultsController
        )
    }
}

// TODO: make it private
class PageFetchResult <FetchObjectType: NSFetchRequestResult, NetworkServiceQuery: NetworkServiceQueryType>: FetchResult<FetchObjectType>
where NetworkServiceQuery.QueryInfo == FetchObjectType.ObjectType.QueryInfo, FetchObjectType: PageModelType {

    private let networkService: NetworkService<FetchObjectType.ObjectType, FetchObjectType>
    private var query: NetworkServiceQuery?
    private let cachePolicy: CachePolicy
    private let pageSize: Int?
    private var numberOfLoadedPages: Int
    private var totalCount: Int

    private var _fetchedResultsController: (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>

    init(networkService service: NetworkService<FetchObjectType.ObjectType, FetchObjectType>, cachePolicy: CachePolicy, pageSize: Int? = nil, fetchedResultsController: @escaping (_ filterId: String) -> NSFetchedResultsController<FetchObjectType>) {

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
            _didUpdate.value = []
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
        print("loadPage \(page)")
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

    override func loadNextPageIfNeeded() {

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

    //MARK: NSFetchedResultsControllerDelegate

    override var numberOfFetchedObjects: Int {
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
        _didUpdate.value = []

        changedItems = []
    }

    override func loadNextPageIfNeeded() {
    }

    //MARK: NSFetchedResultsControllerDelegate

    override func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("✅ controllerDidChangeContent: \(String(describing: fetchedResultsController?.fetchedObjects?.count)), \(numberOfFetchedObjects)")

        if let changedItems = changedItems {
            _didUpdate.value = changedItems
        }
    }

}
