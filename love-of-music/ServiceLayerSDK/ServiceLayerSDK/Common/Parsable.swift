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

protocol Parsable: class {

    associatedtype QueryInfo: QueryInfoType
    associatedtype ParsableContext: Any

    static func identifier(_ json: [String: AnyObject]) throws -> String
    static func objects(_ json: [String: AnyObject]) -> [[String: AnyObject]]?
    static func parsableContext(_ context: ManagedObjectContextType) -> ParsableContext

    func fill(_ json: [String: AnyObject], queryInfo: QueryInfo, context: ParsableContext) throws
    func update(_ json: [String: AnyObject], queryInfo: QueryInfo) throws
}

protocol Paging: class {
    static func totalItems(_ json: [String: AnyObject]) -> Int
}

extension Paging {

    static func totalItems(_ json: [String: AnyObject]) -> Int {
        return 0
    }

}
