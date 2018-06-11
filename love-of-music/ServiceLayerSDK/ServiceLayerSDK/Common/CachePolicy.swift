//
//  CachePolicy.swift
//  Music
//
//  Created by Ruslan Maslouski on 5/29/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

enum CachePolicy {
    case cachedOnly
    case cachedThenLoad
    case cachedElseLoad
    case reloadIgnoringCache
}
