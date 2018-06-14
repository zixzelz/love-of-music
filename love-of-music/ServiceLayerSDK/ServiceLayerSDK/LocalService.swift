//
//  LocalService.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/6/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

protocol LocalServiceQueryType {

    associatedtype QueryInfo: QueryInfoType

    var queryInfo: QueryInfo { get }

    var predicate: NSPredicate? { get }
    var sortBy: [NSSortDescriptor]? { get }
}

extension LocalServiceQueryType {

    var queryInfo: NoneQueryInfo {
        return NoneQueryInfo()
    }
}

internal struct LocalServiceFetchInfo {
    var totalItems: Int
}

class LocalService <ObjectType: ModelType, PageObjectType: PageModelType> {

    typealias LocalServiceFetchCompletionHandler = (ServiceResult<[ObjectType], ServiceError>) -> ()
    typealias LocalServiceCompletionHandler = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()
    typealias EmptyCompletionHandler = (ServiceResult<Void, ServiceError>) -> ()

    private lazy var parsableContext: ObjectType.ParsableContext = {
        let context = ObjectType.managedObjectContext()
        return ObjectType.parsableContext(context)
    }()

    func featchItems < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, fetchLimit: Int? = nil, completionHandler: @escaping LocalServiceFetchCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let context = ObjectType.managedObjectContext()
        context.perform {

            let predicate = query.predicate
            ObjectType.objectsForMainQueue(withPredicate: predicate, fetchLimit: fetchLimit, inContext: context, sortBy: query.sortBy) { (items) in

                let result = items as? [ObjectType] ?? []
                completionHandler(.success(result))
            }
        }
    }

    // json: {"objectsCollection": [{item}, {item}, ...]}
    func parseAndStore <LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], completionHandler: @escaping LocalServiceCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {
        store(query, json: json, completionHandler: completionHandler)
    }

    // json: {"objectsCollection": [{item}, {item}, ...]}
    func parseAndStorePages <LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], range: NSRange, filterId: String, completionHandler: @escaping LocalServiceCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {
        storePage(query, json: json, filterId: filterId, range: range, completionHandler: completionHandler)
    }

    private func store < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], completionHandler: @escaping LocalServiceCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        guard let items = ObjectType.objects(json) else {
            completionHandler(.failure(.wrongResponseFormat))
            return
        }

        let context = ObjectType.managedObjectContext()
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

    private func storePage < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], filterId: String, range: NSRange, completionHandler: @escaping LocalServiceCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {

        guard let items = ObjectType.objects(json) else {
            completionHandler(.failure(.wrongResponseFormat))
            return
        }

        var itemOrder = range.location
        let context = ObjectType.managedObjectContext()
        let parsableContext = self.parsableContext
        context.perform {

            let cachedPageItemsMap = self.pageItemsMap(filterId: filterId, fromOrder: range.location, context: context)
            var handledPageItemsKey = [String]()
            for jsonItem in items {

                guard let identifier = ObjectType.identifier(jsonItem) else {
                    completionHandler(.failure(.wrongResponseFormat))
                    return
                }

                if let cachedPageItem = cachedPageItemsMap[identifier] {
                    cachedPageItem.object.update(jsonItem, queryInfo: query.queryInfo)
                    cachedPageItem.order = itemOrder
                    handledPageItemsKey.append(identifier)
                } else {
                    guard let item = ObjectType.insert(inContext: context) as? ObjectType else {
                        fatalError("Unexpected object type")
                    }
                    item.fill(jsonItem, queryInfo: query.queryInfo, context: parsableContext)
                    _ = PageObjectType(filterId: filterId, object: item, order: itemOrder, inContext: context)
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

    // json: {item}
    private func parseAndStoreItem (_ json: [String: AnyObject], cachedItemsMap: [String: ObjectType], context: ManagedObjectContextType, queryInfo: ObjectType.QueryInfo) throws -> ObjectType {

        var item: ObjectType?

        if let identifier = ObjectType.identifier(json) {
            item = cachedItemsMap[identifier]
        }

        if let _ = item {
            item?.update(json, queryInfo: queryInfo)
        } else {
            item = ObjectType.insert(inContext: context) as? ObjectType
            item?.fill(json, queryInfo: queryInfo, context: parsableContext)
        }
        return item! // todo: throw error
    }

    func cleanCache < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, completionHandler: @escaping EmptyCompletionHandler) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let context = ObjectType.managedObjectContext()
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

    private func pageItemsMap(filterId: String, fromOrder: Int, context: ManagedObjectContextType) -> [String: PageObjectType] {
        let predicate = NSPredicate(format: "filterId == %@ && order >= %d", filterId, fromOrder)
        let result = PageObjectType.objects(withPredicate: predicate, fetchLimit: nil, inContext: context) as? [PageObjectType]

        let map = result?.dict { ($0.object.identifier!, $0) }

        return map ?? [:]
    }
}
