//
//  ModelType.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/11/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

protocol ModelType: Parsable, Paging, ManagedObjectType, ModelUpdating {

}

extension ModelType {

    static func parsableContext(_ context: ManagedObjectContextType) -> Void {

    }

}

protocol PageModelType: ManagedObjectType, ModelUpdating {
    associatedtype ObjectType: ModelType

    var filterId: String { get }
    var object: ObjectType { get }
    var order: Int { get set }

    init(filterId: String, object: ObjectType, order: Int, inContext context: ManagedObjectContextType)
}
