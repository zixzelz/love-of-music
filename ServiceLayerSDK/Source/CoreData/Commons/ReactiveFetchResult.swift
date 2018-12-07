//
//  ReactiveFetchResult.swift
//  greencode-ios-native
//
//  Created by Ruslan Maslouski on 9/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result

class ReactiveFetchResult<FetchObjectType: Equatable>: FetchResultType {

    private let items: Property<[[FetchObjectType]]>

    func numberOfSections() -> Int {
        return items.value.count
    }

    func numberOfRows(inSection section: Int) -> Int {
        return items.value[section].count
    }

    func object(at indexPath: IndexPath) -> FetchObjectType {
        return items.value[indexPath.section][indexPath.row]
    }

    func indexPathForObject(_ object: FetchObjectType) -> IndexPath? {
        for (section, items) in items.value.enumerated() {
            if let row = items.index(of: object) {
                return IndexPath(row: row, section: section)
            }
        }
        return nil
    }

    fileprivate var _state: MutableProperty<FetchResultState>
    lazy var state: Property<FetchResultState> = {
        return Property(_state)
    }()

    var didUpdate: Signal<[UpdateType], NoError>
    private var didUpdateObserver: Signal<[UpdateType], NoError>.Observer

    func loadNextPageIfNeeded() {
    }

    public convenience init(property: Property<[FetchObjectType]>, loadData: (() -> Void)?) {
        let arr = property.map { [$0] }
        self.init(property: arr)

        if let loadData = loadData {
            _state.value = .loading
            loadData()
        }
    }

    public init(property: Property<[[FetchObjectType]]>) {
        _state = MutableProperty(.none)
        (didUpdate, didUpdateObserver) = Signal<[UpdateType], NoError>.pipe()

        self.items = property
        bind()
    }

    private var scopedDisposable: ScopedDisposable<AnyDisposable>?
    private func bind() {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        list += items.producer.startWithValues { [weak self] (items) in
            self?._state.value = .loaded
            self?.didUpdateObserver.send(value: [])
        }
    }
}
