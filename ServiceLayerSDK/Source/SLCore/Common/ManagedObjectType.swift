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

    static func insert(inContext context: ManagedObjectContextType) -> ManagedObjectType
//    static func objectsMap(withPredicate predicate: NSPredicate?, fetchLimit: Int?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?, keyForObject: ((_ object: Self) -> String)?) -> [String: ManagedObjectType]? // By default as Key will be used object identifier
    static func objects(withPredicate predicate: NSPredicate?, fetchLimit: Int?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?) -> [ManagedObjectType]?

//    static func objectsForMainQueue(withPredicate predicate: NSPredicate?, fetchLimit: Int?, inContext context: ManagedObjectContextType, sortBy: [NSSortDescriptor]?, completion: @escaping (_ items: [ManagedObjectType]) -> Void)

    func delete(context: ManagedObjectContextType)
}

public extension ManagedObjectType {

//    static func objectsMap(withPredicate predicate: NSPredicate?, fetchLimit: Int? = nil, inContext context: ManagedObjectContextType, keyForObject: ((_ object: Self) -> String)? = nil) -> [String: ManagedObjectType]? {
//        return objectsMap(withPredicate: predicate, fetchLimit: fetchLimit, inContext: context, sortBy: nil, keyForObject: keyForObject)
//    }

    static func objects(withPredicate predicate: NSPredicate?, fetchLimit: Int? = nil, inContext context: ManagedObjectContextType) -> [ManagedObjectType]? {
        return objects(withPredicate: predicate, fetchLimit: fetchLimit, inContext: context, sortBy: nil)
    }
}

extension ManagedObjectType {

//    public func updateIfNeeded<V: Equatable>(keyPath: ReferenceWritableKeyPath<Self, V>, value: V) {
//        if self[keyPath: keyPath] != value {
//            guard let keyPathString = keyPath._kvcKeyPathString else {
//                self[keyPath: keyPath] = value
//                return
//            }
//            self.setValue(value, forKeyPath: keyPathString)
//        }
//    }

    public func updateIfNeeded<V: Equatable>(keyPath: ReferenceWritableKeyPath<Self, V>, value: V) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    public func updateIfNeeded<V: Equatable>(keyPath: ReferenceWritableKeyPath<Self, V?>, value: V?) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
