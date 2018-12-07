//
//  LocalService.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/6/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

public protocol LocalServiceQueryType {

    associatedtype QueryInfo: QueryInfoType

    var identifier: String { get }
    var queryInfo: QueryInfo { get }

    var predicate: NSPredicate? { get }
    var sortBy: [NSSortDescriptor]? { get }
}

internal struct LocalServiceFetchInfo {
    var totalItems: Int
}

public protocol ContextProvider {
    var workingContext: ManagedObjectContextType { get }
    var mainContext: ManagedObjectContextType { get }
}

public class LocalService <ObjectType: ModelType> {

//    typealias LocalServiceFetchCompletionHandler = (ServiceResult<[ObjectType], ServiceError>) -> ()
    typealias LocalServiceCompletionHandler = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()
    typealias EmptyCompletionHandler = (ServiceResult<Void, ServiceError>) -> ()

    private var contextProvider: ContextProvider

    fileprivate lazy var parsableContext: ObjectType.ParsableContext = {
        return ObjectType.parsableContext(workingContext)
    }()

    var workingContext: ManagedObjectContextType {
        return contextProvider.workingContext
    }

    var mainContext: ManagedObjectContextType {
        return contextProvider.mainContext
    }

    public init(contextProvider: ContextProvider) {
        self.contextProvider = contextProvider
    }

//    func featchItems < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, fetchLimit: Int? = nil, completionHandler: @escaping LocalServiceFetchCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {
//
//        let context = workingContext
//        context.perform {
//
//            let predicate = query.predicate
//            ObjectType.objectsForMainQueue(withPredicate: predicate, fetchLimit: fetchLimit, inContext: context, sortBy: query.sortBy) { (items) in
//
//                let result = items as? [ObjectType] ?? []
//                completionHandler(.success(result))
//            }
//        }
//    }

    // json: {"objectsCollection": [{item}, {item}, ...]}
    func parseAndStore <LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: NSDictionary, range: NSRange?, completionHandler: @escaping LocalServiceCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {
        store(query, json: json, range: range, completionHandler: completionHandler)
    }

    fileprivate func store < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: NSDictionary, range: NSRange?, completionHandler: @escaping LocalServiceCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        guard let items = ObjectType.objects(json) else {
            completionHandler(.failure(.wrongResponseFormat))
            return
        }

        let context = workingContext
        context.perform {

            let cachedItemsMap = self.itemsMap(predicate: query.predicate, sortBy: query.sortBy, context: context)
            var handledItemsKey = [String]()
            for item in items {

                do {
                    let newItem = try self.parseAndStoreItem(item, cachedItemsMap: cachedItemsMap, context: context, queryInfo: query.queryInfo)
                    if let identifier = newItem.identifier {
                        handledItemsKey.append(identifier)
                    }
                } catch let error as ServiceError {

                    completionHandler(.failure(error))
                    return
                } catch {
                    completionHandler(.failure(.internalError))
                    return
                }
            }

            let itemForDelete = cachedItemsMap.filter { !handledItemsKey.contains($0.0) }
            for (_, item) in itemForDelete {
                item.delete(context: context)
            }

            context.saveIfNeeded()

            let totalItems = ObjectType.totalItems(json)
            let info = LocalServiceFetchInfo(totalItems: totalItems)
            completionHandler(.success(info))

        }
    }

// json: {item}
    private func parseAndStoreItem (_ json: NSDictionary, cachedItemsMap: [String: ObjectType], context: ManagedObjectContextType, queryInfo: ObjectType.QueryInfo) throws -> ObjectType {

        do {
            let identifier = try ObjectType.identifier(json)
            var item: ObjectType? = cachedItemsMap[identifier]

            if item == nil {
                item = ObjectType.insert(inContext: context) as? ObjectType
            }
            try item?.fill(json, queryInfo: queryInfo, context: parsableContext)

            return item!
        } catch ParseError.invalidData {
            throw ServiceError.wrongResponseFormat
        }
    }

    func cleanCache < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, completionHandler: @escaping EmptyCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let context = workingContext
        context.perform {

            guard let items = ObjectType.objects(withPredicate: query.predicate, inContext: context) else {
                completionHandler(.failure(.internalError))
                return
            }

            for item in items {
                item.delete(context: context)
            }

            #if DEBUG
                print("Removed cace for: \(items.count) items")
            #endif

            context.saveIfNeeded()
            completionHandler(.success(()))
        }
    }

    private func itemsMap(predicate: NSPredicate?, sortBy: [NSSortDescriptor]?, context: ManagedObjectContextType) -> [String: ObjectType] {
        let result = ObjectType.objects(withPredicate: predicate, fetchLimit: nil, inContext: context, sortBy: sortBy) as? [ObjectType]
        let map = result?.dict { ($0.identifier!, $0) }

        return map ?? [:]
    }
}

public class PageLocalService <ObjectType: ModelType, PageObjectType: PageModelType>: LocalService<ObjectType> {

    override fileprivate func store < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: NSDictionary, range: NSRange?, completionHandler: @escaping LocalServiceCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {

        guard let range = range else {
            assertionFailure("range should not be nil")
            completionHandler(.failure(.internalError))
            return
        }

        guard let items = ObjectType.objects(json) else {
            completionHandler(.failure(.wrongResponseFormat))
            return
        }

        var itemOrder = range.location
        let filterId = query.identifier
        let context = workingContext
        let parsableContext = self.parsableContext
        context.perform {

            let cachedPageItemsMap = self.pageItemsMap(filterId: filterId, fromOrder: range.location, context: context)
            var handledPageItemsKey = [String]()

            for jsonItem in items {

                guard let identifier = try? ObjectType.identifier(jsonItem) else {
                    completionHandler(.failure(.wrongResponseFormat))
                    continue
                }

                if let cachedPageItem = cachedPageItemsMap[identifier] {
                    do {
                        try cachedPageItem.object.fill(jsonItem, queryInfo: query.queryInfo, context: parsableContext)
                        cachedPageItem.updateIfNeeded(keyPath: \PageObjectType.order, value: itemOrder)
                        handledPageItemsKey.append(identifier)
                    } catch { }
                } else {
                    guard let item = ObjectType.insert(inContext: context) as? ObjectType else {
                        fatalError("Unexpected object type")
                    }
                    do {
                        try item.fill(jsonItem, queryInfo: query.queryInfo, context: parsableContext)
                        _ = PageObjectType(filterId: filterId, object: item, order: itemOrder, inContext: context)
                    } catch { }
                }

                itemOrder += 1
            }

            let itemForDelete = cachedPageItemsMap.filter { !handledPageItemsKey.contains($0.0) }
            for (_, page) in itemForDelete {
                page.delete(context: context)
            }

            context.saveIfNeeded()

            let totalItems = ObjectType.totalItems(json)
            let info = LocalServiceFetchInfo(totalItems: totalItems)
            completionHandler(.success(info))
        }
    }

    private func pageItemsMap(filterId: String, fromOrder: Int, context: ManagedObjectContextType) -> [String: PageObjectType] {
        let predicate = NSPredicate(format: "filterId == %@ && order >= %d", filterId, fromOrder)
        let result = PageObjectType.objects(withPredicate: predicate, fetchLimit: nil, inContext: context) as? [PageObjectType]

        let map = result?.dict { ($0.object.identifier!, $0) }

        return map ?? [:]
    }

}
