//
//  TeachersService.swift
//  Music
//
//  Created by Ruslan Maslouski on 5/29/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

typealias TeachersCompletionHandlet = (ServiceResult<[ReleasesEntity], ServiceError>) -> Void

class ReleasesService {

    let localService: LocalService<ReleasesEntity, ReleasesPageEntity>
    let networkService: NetworkService<ReleasesEntity, ReleasesPageEntity>
//    let fetchResult: FetchResult<ReleasesEntity>

    init() {
        localService = LocalService()
        networkService = NetworkService(localService: localService)
//
//        let context = CoreDataHelper.managedObjectContext
//        let fetchRequest = NSFetchRequest<ReleasesEntity>()
//        fetchRequest.entity = NSEntityDescription.entity(forEntityName: String(describing: LGINetworkRecordingFilter.self), in: context)
//        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(LGINetworkRecordingFilter.object)]
//        fetchRequest.predicate = NSPredicate(format: "\(#keyPath(LGINetworkRecordingFilter.identifier)) = %@ && \(#keyPath(LGINetworkRecordingFilter.markedAsDeleted)) = NO", identifier)
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "\(#keyPath(LGINetworkRecordingFilter.index))", ascending: true)]
//        fetchRequest.fetchBatchSize = Constants.pageSize
//
//        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
//        fetchResult = FetchResult<ReleasesEntity>

    }

    func getItems(_ cache: CachePolicy = .cachedElseLoad, completionHandler: @escaping TeachersCompletionHandlet) {
        let query = OjectQuery()
        networkService.fetchData(query, cache: cache, completionHandler: completionHandler)
    }

}

enum OjectQueryInfo: QueryInfoType {
    case `default`
}

class OjectQuery: NetworkServiceQueryType {

    var queryInfo: OjectQueryInfo = .default

    var path: String = "https://api.discogs.com/artists/2/releases"

    var method: NetworkServiceMethod = .GET

    func parameters(range: NSRange?) -> [String: Any]? {
        return range.map { range -> [String: Any] in
            return [
                "per_page": Int(range.length),
                "page": Int(range.location / range.length) + 1
            ]
        }
    }

    var predicate: NSPredicate? = nil

    var sortBy: [NSSortDescriptor]? = [NSSortDescriptor(key: "\(#keyPath(ReleasesEntity.userId))", ascending: true)]

}
