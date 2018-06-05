//
//  ParsableManagedObjectExtension.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 10/18/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import UIKit
import CoreData

extension NSManagedObjectContext: ManagedObjectContextType {
}

extension ManagedObjectType {

    public static func managedObjectContext() -> ManagedObjectContextType {
        return CoreDataHelper.backgroundContext
    }
}

extension ManagedObjectType {

    public static func insert(inContext context: ManagedObjectContextType) -> ManagedObjectType {
        let context = context as! NSManagedObjectContext // TODO: context as generic type?  WARNING

        guard let result: Self = NSEntityDescription.insertNewObject(forEntityName: String(describing: Self.self), into: context) as? Self else {

            fatalError("Unable to insert \(String(describing: self)) in context./n Check if module for Entity is set properly in CoreData model")
        }
        return result
    }

    public static func objectsMap(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?) -> [String: ManagedObjectType]? {

        guard let cacheItems = objects(withPredicate: predicate, inContext: context, sortBy: sortBy) else {
            return nil
        }
        let cacheItemsMap = cacheItems.dict { ($0.identifier ?? UUID().uuidString, $0) }
        return cacheItemsMap
    }

    public static func objects(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?) -> [ManagedObjectType]? {

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: self))
        request.predicate = predicate
        request.sortDescriptors = sortBy

        let result: [Self]? = objects(withRequest: request, inContext: context)
        return result
    }

    public static func objectsForMainQueue(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?, completion: @escaping ([ManagedObjectType]) -> Void) {

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: self))
        request.resultType = .managedObjectIDResultType
        request.predicate = predicate
        request.sortDescriptors = sortBy

        let ids: [NSManagedObjectID] = objects(withRequest: request, inContext: context) ?? []

        DispatchQueue.main.async(execute: {

            let items = self.convertToMainQueue(ids)
            completion(items)
        })
    }

    fileprivate static func objects<T: AnyObject>(withRequest request: NSFetchRequest<NSFetchRequestResult>, inContext context: ManagedObjectContextType) -> [T]? {

        var result: [T]? = nil
        do {
            let context = context as! NSManagedObjectContext // WARNING
            result = try context.fetch(request) as? [T]
        } catch let error {
            assertionFailure("\(error)")
        }
        return result
    }

    fileprivate static func convertToMainQueue(_ itemIds: [NSManagedObjectID]) -> [Self] {

        let mainContext = CoreDataHelper.managedObjectContext

        let items = itemIds.map { mainContext.object(with: $0) } as [AnyObject]
        return items as! [Self]
    }

    public func delete(context: ManagedObjectContextType) {

        let context = context as! NSManagedObjectContext // WARNING
        context.delete(self as! NSManagedObject)
    }

}

protocol ManagedObjectConveniance {
    var objectID: NSManagedObjectID { get }
}

extension NSManagedObject: ManagedObjectConveniance { }
extension ManagedObjectConveniance {

    func convertInContext(_ context: NSManagedObjectContext) -> Self {

        let object = context.object(with: objectID)
        return object as! Self
    }

}
