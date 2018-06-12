//
//  Property.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/12/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation

protocol PropertyProtocol {
    associatedtype InType
    var value: InType { get }

    func observeValues(action: @escaping (_ value: InType) -> Void) -> Disposable
}

protocol Disposable: class {
    func dispose()
}

class Property<InType>: PropertyProtocol {

    typealias Action = (_ value: InType) -> Void

    private var _value: () -> InType
    private var addObserver: (@escaping Action) -> Disposable

    var value: InType {
        return _value()
    }

    init<Property: PropertyProtocol>(_ property: Property) where Property.InType == InType {
        _value = { property.value }
        addObserver = { action in
            return property.observeValues(action: action)
        }
    }

    @discardableResult func observeValues(action: @escaping (_ value: InType) -> Void) -> Disposable {
        return addObserver(action)
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

    @discardableResult func observeValues(action: @escaping (_ value: InType) -> Void) -> Disposable {
        return observer.observeValues(action: action)
    }

}

class CompositeDisposable: Disposable {
    private var disposableList: ContiguousArray<Disposable> = ContiguousArray<Disposable>()

    init(list: [Disposable]) {
        disposableList.append(contentsOf: list)
    }

    init() {
    }

    func dispose() {
        for disposable in disposableList {
            disposable.dispose()
        }
    }

    public static func += (lhs: CompositeDisposable, rhs: Disposable) {
        lhs.add(rhs)
    }

    private func add(_ disposable: Disposable) {
        disposableList.append(disposable)
    }

}

class ScopedDisposable {
    private let compositeDisposable: CompositeDisposable
    init(_ compositeDisposable: CompositeDisposable) {
        self.compositeDisposable = compositeDisposable
    }

    deinit {
        compositeDisposable.dispose()
    }
}

private class Observer<InType> {

    typealias Action = (_ value: InType) -> Void

    private var actions: ContiguousArray<Action> = ContiguousArray<Action>()
    private var tokens: ContiguousArray<Token> = ContiguousArray<Token>()

    private var nextToken: Token = Token(value: 0)

    func observeValues(action: @escaping Action) -> Disposable {

        let token = nextToken
        nextToken = Token(value: token.value)

        actions.append(action)
        tokens.append(token)

        return SimpleDisposable() { [unowned self] in
            self.removeAction(token: token)
        }
    }

    private func removeAction(token: Token) {
        guard let index = self.tokens.index(of: token) else {
            assertionFailure("Unexpected")
            return
        }

        _ = self.actions.remove(at: index)
        _ = self.tokens.remove(at: index)
    }

    func notify(value: InType) {
        for action in actions {
            action(value)
        }
    }
}

private final class SimpleDisposable: Disposable {

    typealias Dispose = () -> Void
    private var disposeBlock: Dispose

    func dispose() {
        disposeBlock()
    }

    init(block: @escaping Dispose) {
        disposeBlock = {
            block()
        }
    }
}

private class Token: Equatable {
    var value: Int
    init(value: Int) {
        self.value = value
    }

    public static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.value == rhs.value
    }

}
