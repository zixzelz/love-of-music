//
//  ModelUpdating.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 7/31/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

protocol ModelUpdating {
}

extension ModelUpdating {
    public func updateIfNeeded<V>(keyPath: ReferenceWritableKeyPath<Self, V>, value: V, force: Bool = false) where V: Equatable {
        if force || self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
