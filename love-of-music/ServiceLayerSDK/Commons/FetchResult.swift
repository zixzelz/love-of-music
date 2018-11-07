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

class StaticFetchResult<FetchObjectType: Equatable>: FetchResultType {

    private let items: [FetchObjectType]

    func numberOfSections() -> Int {
        return 1
    }

    func numberOfRows(inSection section: Int) -> Int {
        return items.count
    }

    func object(at indexPath: IndexPath) -> FetchObjectType {
        return items[indexPath.row]
    }

    func indexPathForObject(_ object: FetchObjectType) -> IndexPath? {
        return items.index(of: object).map { IndexPath(row: $0, section: 0) }
    }

    fileprivate var _state: MutableProperty<FetchResultState>
    lazy var state: Property<FetchResultState> = {
        return Property(_state)
    }()

    var didUpdate: Signal<[UpdateType], NoError>
    private var didUpdateObserver: Signal<[UpdateType], NoError>.Observer

    func loadNextPageIfNeeded() {
    }

    init(items: [FetchObjectType]) {
        _state = MutableProperty(.none)
        (didUpdate, didUpdateObserver) = Signal<[UpdateType], NoError>.pipe()

        self.items = items

        _state.value = .loaded
        didUpdateObserver.send(value: [])
    }

}
