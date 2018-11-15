//
//  FetchResult.swift
//  Music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData
import ReactiveSwift
import Result

enum FetchResultState: Equatable {
    case none, loading, loaded
    public static func == (lhs: FetchResultState, rhs: FetchResultState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.loading, .loading):
            return true
        case (.loaded, .loaded):
            return true
        default:
            return false
        }
    }
}

enum UpdateType {
    case insert(IndexPath), update(IndexPath), delete(IndexPath), move(IndexPath, IndexPath)
}

protocol FetchResultType: class {
    associatedtype FetchObjectType

    func numberOfSections() -> Int
    func numberOfRows(inSection section: Int) -> Int
    func object(at indexPath: IndexPath) -> FetchObjectType
    func indexPathForObject(_ object: FetchObjectType) -> IndexPath?

    var state: Property<FetchResultState> { get }
    var didUpdate: Signal<[UpdateType], NoError> { get }

    func loadNextPageIfNeeded()
}

class FetchResult <FetchObjectType>: NSObject, FetchResultType {

    var state: Property<FetchResultState> {
        preconditionFailure("Must be overriden")
    }

    var didUpdate: Signal<[UpdateType], NoError> {
        preconditionFailure("Must be overriden")
    }

    func numberOfSections() -> Int {
        preconditionFailure("Must be overriden")
    }

    func numberOfRows(inSection section: Int) -> Int {
        preconditionFailure("Must be overriden")
    }

    func object(at indexPath: IndexPath) -> FetchObjectType {
        preconditionFailure("Must be overriden")
    }

    func indexPathForObject(_ object: FetchObjectType) -> IndexPath? {
        preconditionFailure("Must be overriden")
    }

    func loadNextPageIfNeeded() {
        preconditionFailure("Should be overriden")
    }
}

class StaticFetchResult<FetchObjectType: Equatable>: FetchResult<FetchObjectType> {

    private let items: [FetchObjectType]

    override func numberOfSections() -> Int {
        return 1
    }

    override func numberOfRows(inSection section: Int) -> Int {
        return items.count
    }

    override func object(at indexPath: IndexPath) -> FetchObjectType {
        return items[indexPath.row]
    }

    override func indexPathForObject(_ object: FetchObjectType) -> IndexPath? {
        return items.index(of: object).map { IndexPath(row: $0, section: 0) }
    }

    fileprivate var _state: MutableProperty<FetchResultState>
    private lazy var stateProperty: Property<FetchResultState> = {
        return Property(_state)
    }()
    override var state: Property<FetchResultState> {
        return stateProperty
    }

    fileprivate var didUpdateObserver: Signal<[UpdateType], NoError>.Observer
    private var didUpdateSignal: Signal<[UpdateType], NoError>
    override var didUpdate: Signal<[UpdateType], NoError> {
        return didUpdateSignal
    }

    init(items: [FetchObjectType]) {
        _state = MutableProperty(.none)
        (didUpdateSignal, didUpdateObserver) = Signal<[UpdateType], NoError>.pipe()

        self.items = items

        _state.value = .loaded
        didUpdateObserver.send(value: [])
    }

}
