//
//  ManagedObjectType.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/6/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

public protocol ManagedObjectContextType {
    func perform(_ block: @escaping () -> Swift.Void)
    func saveIfNeeded()
}

public protocol ManagedObjectType: class {
    var identifier: String? { get } // should use nil as identifier when items of response doesn't have identifier

    static func managedObjectContext() -> ManagedObjectContextType

    static func insert(inContext context: ManagedObjectContextType) -> ManagedObjectType
    static func objectsMap(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?) -> [String: ManagedObjectType]?
    static func objects(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?) -> [ManagedObjectType]?

    static func objectsForMainQueue(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?, completion: @escaping (_ items: [ManagedObjectType]) -> Void)

    func delete(context: ManagedObjectContextType)
}

extension ManagedObjectType {

    static func objectsMap(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType) -> [String: ManagedObjectType]? {
        return objectsMap(withPredicate: predicate, inContext: context, sortBy: nil)
    }

    static func objects(withPredicate predicate: NSPredicate?, inContext context: ManagedObjectContextType) -> [ManagedObjectType]? {
        return objects(withPredicate: predicate, inContext: context, sortBy: nil)
    }
}
