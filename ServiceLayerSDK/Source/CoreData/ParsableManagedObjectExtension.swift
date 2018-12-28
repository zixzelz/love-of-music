//
//  ParsableManagedObjectExtension.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 10/18/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import UIKit
import CoreData

public extension ManagedObjectType {

    public static func insert(inContext context: ManagedObjectContextType) -> ManagedObjectType {
        guard let context = context as? NSManagedObjectContext else {
            fatalError("Unexpected context type")
        }

        guard let result: Self = NSEntityDescription.insertNewObject(forEntityName: String(describing: Self.self), into: context) as? Self else {

            fatalError("Unable to insert \(String(describing: self)) in context./n Check if module for Entity is set properly in CoreData model")
        }
        return result
    }

    //todo refactoring
    public static func objectsMap(withPredicate predicate: NSPredicate?, fetchLimit: Int? = nil, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?, keyForObject: ((_ object: Self) -> String)?) -> [String: Self]? {

        guard let cacheItems = objects(withPredicate: predicate, fetchLimit: fetchLimit, inContext: context, sortBy: sortBy) as? [Self] else {
            return nil
        }
        let cacheItemsMap = cacheItems.dict { (keyForObject?($0) ?? $0.identifier, $0) }
        return cacheItemsMap
    }

    public static func objects(withPredicate predicate: NSPredicate?, fetchLimit: Int? = nil, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?) -> [ManagedObjectType]? {

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: self))
        request.predicate = predicate
        request.sortDescriptors = sortBy

        if let fetchLimit = fetchLimit {
            request.fetchLimit = fetchLimit
        }

        let result: [Self]? = objects(withRequest: request, inContext: context)
        return result
    }

    fileprivate static func objects<T: AnyObject>(withRequest request: NSFetchRequest<NSFetchRequestResult>, inContext context: ManagedObjectContextType) -> [T]? {

        var result: [T]? = nil
        do {
            guard let context = context as? NSManagedObjectContext else {
                fatalError("Unexpected context type")
            }
            result = try context.fetch(request) as? [T]
        } catch let error {
            assertionFailure("\(error)")
        }
        return result
    }

    public func delete(context: ManagedObjectContextType) {
        guard let context = context as? NSManagedObjectContext else {
            fatalError("Unexpected context type")
        }
        context.delete(self as! NSManagedObject)
    }

    public static func delete(in context: ManagedObjectContextType, with predicate: NSPredicate? = nil, includesSubentities: Bool = true) {
        guard let context = context as? NSManagedObjectContext else {
            fatalError("Unexpected context type")
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: self))
        fetchRequest.includesSubentities = includesSubentities
        fetchRequest.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch let error {
            print("[ManagedObjectType] delete error: \(error)")
        }
    }

}

//protocol ManagedObjectConveniance {
//    var objectID: NSManagedObjectID { get }
//}

public extension NSFetchRequestResult where Self: NSManagedObject {
    public func existingObject(in context: NSManagedObjectContext) -> Self? {
        guard let object = try? context.existingObject(with: objectID) else {
            return nil
        }
        return object as? Self
    }
}
