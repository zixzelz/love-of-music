//
//  TeachersService.swift
//  Music
//
//  Created by Ruslan Maslouski on 5/29/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import ServiceLayerSDK
import ReactiveSwift
import CoreData

typealias ReleasesCompletionHandlet = (ServiceResult<[ReleasesEntity], ServiceError>) -> Void

class ReleasesService {

    let localService: PageLocalService<ReleasesEntity, ReleasesPageEntity>
    let networkService: NetworkService<ReleasesEntity>

    init() {
        localService = PageLocalService(contextProvider: CoreDataHelper.contextProvider())
        networkService = NetworkService(localService: localService)
    }

//    func getItems(_ cache: CachePolicy = .CachedThenLoad, completionHandler: @escaping TeachersCompletionHandlet) {
//        let query = ReleasesQuery()
//        networkService.fetchData(query, cache: cache, completionHandler: completionHandler)
//    }
//
    func getItemsPage(_ cache: CachePolicy = .cachedThenLoad, range: NSRange?) -> SignalProducer<ServiceResponse<ReleasesEntity>, ServiceError> {
        let query = ReleasesQuery()
        return networkService.loadNewData(query, cache: cache, range: range)
    }

}

enum ReleasesQueryInfo: QueryInfoType {
    case `default`
}

struct ReleasesQuery: NetworkServiceQueryType {

    var queryInfo: ReleasesQueryInfo = .default

    var identifier: String {
        return filterIdentifier
    }

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

    struct Mapper {

        struct ItemMap: MapperProtocol {
            let dict: NSDictionary

            public init(_ dict: NSDictionary) {
                self.dict = dict
            }

            static func identifier(_ object: NSDictionary) -> String? {
                return object.int(for: "id").map({ String($0) })
            }

            var identifier: String? {
                return type(of: self).identifier(dict)
            }

            var title: String? {
                return dict.string(for: "title")
            }
        }

        let dict: NSDictionary

        public init(_ dict: NSDictionary) {
            self.dict = dict
        }

        var items: [NSDictionary]? {
            return dict.dictArr(for: "releases")
        }

        var totalItems: Int {
            return dict.dict(for: "pagination")?.int(for: "items") ?? 0
        }

    }

    typealias QueryInfo = ReleasesQueryInfo

    static func identifier(_ json: NSDictionary) throws -> String {
        let mapper = Mapper.ItemMap(json)
        guard let id = mapper.identifier else {
            throw ParseError.invalidData
        }
        return id
    }

    static func objects(_ json: NSDictionary) -> [NSDictionary]? {
        let mapper = Mapper(json)
        return mapper.items
    }

    func fill(_ json: NSDictionary, queryInfo: QueryInfo, context: Void) throws {
        let identifier = try ReleasesEntity.identifier(json)

        let mapper = Mapper.ItemMap(json)
        updateIfNeeded(keyPath: \ReleasesEntity.userId, value: identifier)
        updateIfNeeded(keyPath: \ReleasesEntity.title, value: mapper.title)
    }

    // MARK: - Paging

    static func totalItems(_ json: NSDictionary) -> Int {
        let mapper = Mapper(json)
        return mapper.totalItems
    }

    // MARK: - ManagedObjectType

    var identifier: String {
        return userId
    }

}
