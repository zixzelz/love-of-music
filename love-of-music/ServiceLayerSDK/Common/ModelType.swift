//
//  ModelType.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/11/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

protocol ModelType: Parsable, ManagedObjectType {

}

protocol PageModelType: ManagedObjectType {
    associatedtype ObjectType: ModelType

    var pageId: String { get }
    var object: ObjectType { get }
    var order: Int { get set }

    init(pageId: String, object: ObjectType, order: Int, inContext context: ManagedObjectContextType)
}
