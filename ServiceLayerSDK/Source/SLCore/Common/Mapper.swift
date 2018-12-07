//
//  Mapper.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 30/10/2018.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation

public protocol MapperProtocol {
    associatedtype Identifier: Hashable
    static func identifier(_ object: NSDictionary) -> Identifier?
}
