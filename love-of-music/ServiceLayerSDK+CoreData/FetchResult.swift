//
//  FetchResult.swift
//  Music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

class FetchResult < ObjectType, PageObjectType: PageModelType & NSFetchRequestResult, NetworkServiceQuery: NetworkServiceQueryType >: NSObject, NSFetchedResultsControllerDelegate where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {

    private let networkService: NetworkService<ObjectType, PageObjectType>
    private var query: NetworkServiceQuery?
    private let cachePolicy: CachePolicy
    private let pageSize: Int?
    private var numberOfLoadedPages: Int

    private let fetchedResultsController: NSFetchedResultsController<PageObjectType>

    init(networkService service: NetworkService<ObjectType, PageObjectType>, cachePolicy: CachePolicy, pageSize: Int? = nil) { //} where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {

        self.networkService = service
        self.cachePolicy = cachePolicy
        self.pageSize = pageSize
        self.numberOfLoadedPages = 0

        fetchedResultsController = FetchResult.makeFetchedResultsController(pageSize: pageSize)

        super.init()

        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
    }

    func performFetch(query: NetworkServiceQuery) {
        self.query = query

        let filterId = query.filterIdentifier
        updateFetchedResultsController(filterId: filterId)

        fetchNextPage()
    }

    private func fetchNextPage() {

        guard let query = query else {
            return
        }

        let range = pageSize.map { NSRange(location: numberOfLoadedPages * $0, length: $0) }

        networkService.fetchData(query, cache: cachePolicy, range: range) { [weak self] (result) in
            guard case .success(let items) = result else {
                print("error: \(result)")
                return
            }
            self?.numberOfLoadedPages += 1
            print("result: \(items.count)\n\(items)")
        }

    }

    private func updateFetchedResultsController(filterId: String) {
        let predicate = NSPredicate(format: "filterId = %@", filterId) //#keyPath(ReleasesPageEntity.filterId)
        fetchedResultsController.fetchRequest.predicate = predicate
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: nil)
        try? fetchedResultsController.performFetch()
    }

    //MARK: NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("controllerDidChangeContent: \(controller)")
    }

}

private extension FetchResult {

    private static func makeFetchedResultsController(pageSize: Int?) -> NSFetchedResultsController<PageObjectType> {
        let context = CoreDataHelper.managedObjectContext

        let fetchRequest = NSFetchRequest<PageObjectType>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: ReleasesPageEntity.self), in: context)
        fetchRequest.relationshipKeyPathsForPrefetching = ["object"] //#keyPath(PageModelType.object)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)] //#keyPath(PageObjectType.order)

        if let pageSize = pageSize {
            fetchRequest.fetchBatchSize = pageSize
        }

        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    }
}
