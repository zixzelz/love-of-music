//
//  Array+Dict.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/3/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

extension Array {
    func dict<K,V>(_ transform: (Element) -> (K,V)) -> [K:V] {
        
        var res = [K:V](minimumCapacity: count)
        for value in self {
            
            let c = transform(value)
            res[c.0] = c.1
        }
        return res
    }
}
