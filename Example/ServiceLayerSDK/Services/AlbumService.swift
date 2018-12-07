//
//  SearchService.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ServiceLayerSDK

class AlbumService {

    let localService: PageLocalService<AlbumEntity, AlbumPageEntity>
    let networkService: NetworkService<AlbumEntity>

    init() {
        localService = PageLocalService(contextProvider: CoreDataHelper.contextProvider())
        networkService = NetworkService(localService: localService)
    }

}

enum AlbumQueryInfo: QueryInfoType {
    case query(text: String)
    case album(text: String)
    case `default`
}

class AlbumQuery: NetworkServiceQueryType {

    var queryInfo: AlbumQueryInfo = .default

    var identifier: String {
        return filterIdentifier
    }

    init(queryInfo: AlbumQueryInfo) {
        self.queryInfo = queryInfo
    }

    var path: String = "https://api.discogs.com/database/search"

    var method: NetworkServiceMethod = .GET

    func parameters(range: NSRange?) -> [String: String]? {

        var list = [String: String]()
        switch queryInfo {
        case .query(let text):
            list["q"] = text
        case .album(let text):
            list["q"] = text
            list["type"] = "artist"
        case .default: break
        }

        list["key"] = "bQOLwOvcehVBchRvdQev"
        list["secret"] = "lHECHYPFPvIkHeHwWbFbCdHWjHPdhSHF"

        if let range = range {
            list["per_page"] = String(range.length)
            list["page"] = String(Int(range.location / range.length) + 1)
        }
        return list
    }

    var predicate: NSPredicate? = nil

    var sortBy: [NSSortDescriptor]? = [NSSortDescriptor(key: "\(#keyPath(ReleasesEntity.userId))", ascending: true)]

}

extension AlbumEntity: ModelType {

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

            var thumb: String? {
                return dict.string(for: "thumb")
            }

            var country: String? {
                return dict.string(for: "country")
            }

            var year: String? {
                return dict.string(for: "year")
            }

            var albumType: String? {
                return dict.string(for: "type")
            }

            var genre: String? {
                return dict.arr(for: "genre").map { $0.joined(separator: ", ") }
            }

            var style: String? {
                return dict.arr(for: "style").map { $0.joined(separator: ", ") }
            }
        }

        let dict: NSDictionary

        public init(_ dict: NSDictionary) {
            self.dict = dict
        }

        var items: [NSDictionary]? {
            return dict.dictArr(for: "results")
        }

        var totalItems: Int {
            return dict.dict(for: "pagination")?.int(for: "items") ?? 0
        }

    }

    typealias QueryInfo = AlbumQueryInfo

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
        let identifier = try AlbumEntity.identifier(json)

        let mapper = Mapper.ItemMap(json)
        updateIfNeeded(keyPath: \AlbumEntity.albumId, value: identifier)
        updateIfNeeded(keyPath: \AlbumEntity.title, value: mapper.title)
        updateIfNeeded(keyPath: \AlbumEntity.thumb, value: mapper.thumb)
        updateIfNeeded(keyPath: \AlbumEntity.country, value: mapper.country)
        updateIfNeeded(keyPath: \AlbumEntity.year, value: mapper.year)
        updateIfNeeded(keyPath: \AlbumEntity.genre, value: mapper.genre)
        updateIfNeeded(keyPath: \AlbumEntity.albumType, value: mapper.albumType)
        updateIfNeeded(keyPath: \AlbumEntity.style, value: mapper.style)
    }

    // MARK: - Paging

    static func totalItems(_ json: NSDictionary) -> Int {
        let mapper = Mapper(json)
        return mapper.totalItems
    }

    // MARK: - ManagedObjectType

    var identifier: String? {
        return albumId
    }

}
