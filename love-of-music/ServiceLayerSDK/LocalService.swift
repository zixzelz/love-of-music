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

class LocalService <ObjectType: ModelType, PageObjectType: PageModelType> {

    typealias LocalServiceFetchCompletionHandlet = (ServiceResult<[ObjectType], ServiceError>) -> ()
    typealias LocalServiceCompletionHandlet = (ServiceResult<Void, ServiceError>) -> ()

    private lazy var parsableContext: ObjectType.ParsableContext = {
        let context = ObjectType.managedObjectContext()
        return ObjectType.parsableContext(context)
    }()

    func featch < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, fetchLimit: Int? = nil, completionHandler: @escaping LocalServiceFetchCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

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
    func parseAndStore <LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], completionHandler: @escaping LocalServiceCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {
        store(query, json: json, completionHandler: completionHandler)
    }

    // json: {"objectsCollection": [{item}, {item}, ...]}
    func parseAndStorePages <LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], range: NSRange, pageId: String, completionHandler: @escaping LocalServiceCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {
        storePage(query, json: json, pageId: pageId, range: range, completionHandler: completionHandler)
    }

    private func store < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], completionHandler: @escaping LocalServiceCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

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
            completionHandler(.success(()))
        }
    }

    private func storePage < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], pageId: String, range: NSRange, completionHandler: @escaping LocalServiceCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo, PageObjectType.ObjectType == ObjectType {

        guard let items = ObjectType.objects(json) else {
            completionHandler(.failure(.wrongResponseFormat))
            return
        }

        var pageOrder = range.location
        let context = ObjectType.managedObjectContext()
        let parsableContext = self.parsableContext
        context.perform {

            let cachedPageItemsMap = self.pageItemsMap(pageId: pageId, fetchLimit: range.length, context: context)
            var handledPageItemsKey = [String]()
            for item in items {

                guard let identifier = ObjectType.identifier(item) else {
                    completionHandler(.failure(.wrongResponseFormat))
                    return
                }

                if let cachedPageItem = cachedPageItemsMap[identifier] {
                    cachedPageItem.object.update(json, queryInfo: query.queryInfo)
                    cachedPageItem.order = pageOrder
                    handledPageItemsKey.append(identifier)
                } else {
                    guard let item = ObjectType.insert(inContext: context) as? ObjectType else {
                        fatalError("Unexpected object type")
                    }
                    item.fill(json, queryInfo: query.queryInfo, context: parsableContext)
                    _ = PageObjectType(pageId: pageId, object: item, order: pageOrder, inContext: context)
                }

                pageOrder += 1
            }

            let itemForDelete = cachedPageItemsMap.filter { !handledPageItemsKey.contains($0.0) }
            for (_, page) in itemForDelete {
                page.delete(context: context)
            }

            context.saveIfNeeded()
            completionHandler(.success(()))
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

    func cleanCache < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, completionHandler: @escaping LocalServiceCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

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

    private func pageItemsMap(pageId: String, fetchLimit: Int, context: ManagedObjectContextType) -> [String: PageObjectType] {
        let predicate = NSPredicate(format: "pageId == %@", pageId)
        let result = PageObjectType.objects(withPredicate: predicate, fetchLimit: fetchLimit, inContext: context) as? [PageObjectType]

        let map = result?.dict { ($0.object.identifier!, $0) }

        return map ?? [:]
    }
}
