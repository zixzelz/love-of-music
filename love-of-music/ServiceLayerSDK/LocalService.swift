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

class LocalService <ObjectType: ModelType> {

    typealias LocalServiceFetchCompletionHandlet = (ServiceResult<[ObjectType], ServiceError>) -> ()
    typealias LocalServiceCompletionHandlet = (ServiceResult<Void, ServiceError>) -> ()

    var predicate: NSPredicate?
    private lazy var cachedItemsMap: [String: ObjectType] = {
        let context = ObjectType.managedObjectContext()

        let result = ObjectType.objectsMap(withPredicate: self.predicate, inContext: context) as? [String: ObjectType]
        return result ?? [:]
    }()

    private lazy var parsableContext: ObjectType.ParsableContext = {
        let context = ObjectType.managedObjectContext()
        return ObjectType.parsableContext(context)
    }()

    func featch < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, completionHandler: @escaping LocalServiceFetchCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let context = ObjectType.managedObjectContext()
        context.perform {

            ObjectType.objectsForMainQueue(withPredicate: query.predicate, inContext: context, sortBy: query.sortBy) { (items) in

                let result = items as? [ObjectType] ?? []
                completionHandler(.success(result))
            }
        }
    }

    // json: {"objectsCollection": [{item}, {item}, ...]}
    func parseAndStore < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], completionHandler: @escaping LocalServiceCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        prepareService(query)
        store(query, json: json, completionHandler: completionHandler)
    }

    // json: {item}
    func parseAndStoreItem (_ json: [String: AnyObject], context: ManagedObjectContextType, queryInfo: ObjectType.QueryInfo) throws -> ObjectType {

        var item: ObjectType?

        if let keyForIdentifier = ObjectType.keyForIdentifier() {
            guard let identifier = json[keyForIdentifier] as? String else {
                throw ServiceError.wrongResponseFormat
            }

            item = cachedItemsMap[identifier]
        }

        if let _ = item {
            item?.update(json, queryInfo: queryInfo)
        } else {
            item = ObjectType.insert(inContext: context) as? ObjectType
            item?.fill(json, queryInfo: queryInfo, context: parsableContext)

            if let identifier = item?.identifier {
                cachedItemsMap[identifier] = item
            }
        }
        return item!
    }

    fileprivate func prepareService < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {
        predicate = query.predicate
    }

    fileprivate func store < LocalServiceQuery: LocalServiceQueryType> (_ query: LocalServiceQuery, json: [String: AnyObject], completionHandler: @escaping LocalServiceCompletionHandlet) where LocalServiceQuery.QueryInfo == ObjectType.QueryInfo {

        guard let items = ObjectType.objects(json) else {
            completionHandler(.failure(.wrongResponseFormat))
            return
        }

        let context = ObjectType.managedObjectContext()
        context.perform {

            let cachedItemsMap = self.cachedItemsMap
            var handledItemsKey = [String]()
            for item in items {

                do {
                    let newItem = try self.parseAndStoreItem(item, context: context, queryInfo: query.queryInfo)
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

}
