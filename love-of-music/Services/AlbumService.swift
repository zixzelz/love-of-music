//
//  SearchService.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import CoreData

class AlbumService {

    let localService: LocalService<AlbumEntity, AlbumPageEntity>
    let networkService: NetworkService<AlbumEntity, AlbumPageEntity>

    init() {
        localService = LocalService()
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

    typealias QueryInfo = AlbumQueryInfo

    static func identifier(_ json: [String: AnyObject]) throws -> String {
        guard let id = json.int(for: "id").map({ String($0) }) else {
            throw ParseError.invalidData
        }
        return id
    }

    static func objects(_ json: [String: AnyObject]) -> [[String: AnyObject]]? {

        return json["results"] as? [[String: AnyObject]]
    }

    func fill(_ json: [String: AnyObject], queryInfo: QueryInfo, context: Void) throws {
        albumId = try AlbumEntity.identifier(json)
        try update(json, queryInfo: queryInfo)
    }

    func update(_ json: [String: AnyObject], queryInfo: QueryInfo) throws {
        updateIfNeeded(keyPath: \AlbumEntity.title, value: json.string(for: "title"), force: false)
        updateIfNeeded(keyPath: \AlbumEntity.thumb, value: json.string(for: "thumb"), force: false)
        updateIfNeeded(keyPath: \AlbumEntity.country, value: json.string(for: "country"), force: false)
        updateIfNeeded(keyPath: \AlbumEntity.year, value: json.string(for: "year"), force: false)
        updateIfNeeded(keyPath: \AlbumEntity.type, value: json.string(for: "type"), force: false)

        let genre = json.arr(for: "genre")?.joined(separator: ", ")
        updateIfNeeded(keyPath: \AlbumEntity.genre, value: genre, force: false)

        let style = json.arr(for: "style")?.joined(separator: ", ")
        updateIfNeeded(keyPath: \AlbumEntity.style, value: style, force: false)
    }

    // MARK: - Paging

    static func totalItems(_ json: [String: AnyObject]) -> Int {
        return json.dictValue(for: "pagination").intValue(for: "items")
    }

    // MARK: - ManagedObjectType

    var identifier: String? {
        return albumId
    }

}
