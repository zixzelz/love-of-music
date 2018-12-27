//
//  Parsable.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/6/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

public enum ParseError: Error {
    case invalidData
}

public protocol Parsable: class {

    associatedtype QueryInfo: QueryInfoType
    associatedtype ParsableContext: Any

    static func identifier(_ json: NSDictionary) throws -> String // ParseError
    static func objects(_ json: NSDictionary) -> [NSDictionary]?
    static func parsableContext(_ context: ManagedObjectContextType) -> ParsableContext

    func fill(_ json: NSDictionary, queryInfo: QueryInfo, context: ParsableContext) throws // ParseError
}

public protocol Paging: class {
    static func totalItems(_ json: NSDictionary) -> Int
}

extension Paging {

    static func totalItems(_ json: NSDictionary) -> Int {
        return 0
    }

}
