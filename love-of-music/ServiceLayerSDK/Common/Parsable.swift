//
//  Parsable.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/6/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

protocol Parsable: class {

    associatedtype QueryInfo: QueryInfoType
    associatedtype ParsableContext: Any

    static func identifier(_ json: [String: AnyObject]) -> String? // should use nil as identifier when items of response doesn't have identifier
    static func objects(_ json: [String: AnyObject]) -> [[String: AnyObject]]?
    static func parsableContext(_ context: ManagedObjectContextType) -> ParsableContext

    func fill(_ json: [String: AnyObject], queryInfo: QueryInfo, context: ParsableContext) // TODO: [!] add possibility to throw error in case when required fields are empty
    func update(_ json: [String: AnyObject], queryInfo: QueryInfo)
}

extension Parsable {

    static func parsableContext(_ context: ManagedObjectContextType) -> Void {

    }

}
