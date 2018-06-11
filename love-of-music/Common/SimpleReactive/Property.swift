//
//  Property.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/12/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

protocol PropertyProtocol {
    associatedtype InType
    var value: InType { get }

    func observeValues(action: @escaping (_ value: InType) -> Void)
}

class Property<InType>: PropertyProtocol {

    typealias Action = (_ value: InType) -> Void

    private var _value: () -> InType
    private var addObserver: (@escaping Action) -> Void

    var value: InType {
        return _value()
    }

    init<Property: PropertyProtocol>(_ property: Property) where Property.InType == InType {
        _value = { property.value }
        addObserver = { action in
            property.observeValues(action: action)
        }
    }

    func observeValues(action: @escaping (_ value: InType) -> Void) {
        addObserver(action)
    }

}

class MutableProperty<InType>: PropertyProtocol {

    private var observer: Observer<InType>
    var value: InType {
        didSet {
            observer.notify(value: value)
        }
    }

    init(value: InType) {
        observer = Observer()
        self.value = value
    }

    func observeValues(action: @escaping (_ value: InType) -> Void) {
        observer.observeValues(action: action)
    }

}

private class Observer<InType> {

    typealias Action = (_ value: InType) -> Void

    private var actions: [Action] = [Action]()

    func observeValues(action: @escaping Action) {
        actions.append(action)
    }

    func notify(value: InType) {
        for action in actions {
            action(value)
        }
    }
}
