//
//  TeachersService.swift
//  Music
//
//  Created by Ruslan Maslouski on 5/29/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

typealias ReleasesCompletionHandlet = (ServiceResult<[ReleasesEntity], ServiceError>) -> Void

class ReleasesService {

    let localService: LocalService<ReleasesEntity, ReleasesPageEntity>
    let networkService: NetworkService<ReleasesEntity, ReleasesPageEntity>

    init() {
        localService = LocalService()
        networkService = NetworkService(localService: localService)
    }

//    func getItems(_ cache: CachePolicy = .CachedThenLoad, completionHandler: @escaping TeachersCompletionHandlet) {
//        let query = ReleasesQuery()
//        networkService.fetchData(query, cache: cache, completionHandler: completionHandler)
//    }
//
//    func getItemsPage(_ cache: CachePolicy = .CachedThenLoad, range: NSRange, completionHandler: @escaping TeachersCompletionHandlet) {
//        let query = ReleasesQuery()
//        networkService.fetchData(query, cache: cache, range: range, completionHandler: completionHandler)
//    }

}

enum ReleasesQueryInfo: QueryInfoType {
    case `default`
}

class ReleasesQuery: NetworkServiceQueryType {

    var queryInfo: ReleasesQueryInfo = .default

    var path: String = "https://api.discogs.com/artists/2/releases"

    var method: NetworkServiceMethod = .GET

    func parameters(range: NSRange?) -> [String: String]? {
        return range.map { range -> [String: String] in
            return [
                "per_page": String(range.length),
                "page": String(Int(range.location / range.length) + 1)
            ]
        }
    }

    var predicate: NSPredicate? = nil

    var sortBy: [NSSortDescriptor]? = [NSSortDescriptor(key: "\(#keyPath(ReleasesEntity.userId))", ascending: true)]

}

extension ReleasesEntity: ModelType {

    typealias QueryInfo = ReleasesQueryInfo

    static func identifier(_ json: [String: AnyObject]) -> String? {
        let id = json["id"] as? Int
        return id.map { String($0) }
    }

    static func objects(_ json: [String: AnyObject]) -> [[String: AnyObject]]? {

        return json["releases"] as? [[String: AnyObject]]
    }

    func fill(_ json: [String: AnyObject], queryInfo: QueryInfo, context: Void) {
        userId = ReleasesEntity.identifier(json)!
        update(json, queryInfo: queryInfo)
    }

    func update(_ json: [String: AnyObject], queryInfo: QueryInfo) {
        title = json["title"] as? String
    }

    // MARK: - ManagedObjectType

    var identifier: String? {
        return userId
    }

}
