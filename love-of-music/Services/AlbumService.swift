//
//  SearchService.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

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

    static func identifier(_ json: [String: AnyObject]) -> String? {
        let id = json["id"] as? Int
        return id.map { String($0) }
    }

    static func objects(_ json: [String: AnyObject]) -> [[String: AnyObject]]? {

        return json["results"] as? [[String: AnyObject]]
    }

    func fill(_ json: [String: AnyObject], queryInfo: QueryInfo, context: Void) {
        albumId = ReleasesEntity.identifier(json)!
        update(json, queryInfo: queryInfo)
    }

    func update(_ json: [String: AnyObject], queryInfo: QueryInfo) {
        title = json["title"] as? String
        thumb = json["thumb"] as? String
        country = json["country"] as? String
        year = json["year"] as? String
        genre = json["genre"] as? String
        type = json["type"] as? String

        if let genres = json["genre"] as? NSArray {
            genre = genres.componentsJoined(by: ", ")
        }

        if let styles = json["style"] as? NSArray {
            style = styles.componentsJoined(by: ", ")
        }
    }

    // MARK: - Paging

    static func totalItems(_ json: [String: AnyObject]) -> Int {
        return json["pagination"]?["items"] as? Int ?? 0
    }

    // MARK: - ManagedObjectType

    var identifier: String? {
        return albumId
    }

}
