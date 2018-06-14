//
//  Array+Dict.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/3/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

extension Array {
    func dict<K, V>(_ transform: (Element) -> (K, V)) -> [K: V] {

        var res = [K: V](minimumCapacity: count)
        for value in self {

            let c = transform(value)
            if res[c.0] == nil {
                res[c.0] = c.1
            } else {
                assertionFailure("Duplicated id")
                let id = UUID().uuidString as! K
                res[id] = c.1
            }
        }
        return res
    }
}
