//
//  NSManagedObject.swift
//  ServiceLayerSDK
//
//  Created by Ruslan Maslouski on 04/12/2018.
//

import CoreData

extension NSFetchRequestResult where Self: NSManagedObject {
    public static func insert(inContext: NSManagedObjectContext) -> Self {
        guard let result: Self = NSEntityDescription.insertNewObject(forEntityName: String(describing: Self.self), into: inContext) as? Self else {
            fatalError("Unable to insert \(String(describing: self)) in context")
        }
        return result
    }
}
