//
//  ListViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/8/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import CoreData

protocol ListViewModelType {
    associatedtype CellViewModel

    var state: Property<FetchResultState> { get }
    var didUpdate: Property<[UpdateType]> { get }

    var numberOfItems: Int { get }
    func cellViewModel(at indexpath: IndexPath) -> CellViewModel

    func loadNextPageIfNeeded()

    var selectedCells: Property<Set<IndexPath>> { get }
    func selectRowAtIndexPath(_ indexPath: IndexPath)
    func deselectRowAtIndexPath(_ indexPath: IndexPath)
    func resetSelection()
}

class ListViewModel<CellViewModel>: ListViewModelType {

    var state: Property<FetchResultState> {
        preconditionFailure("Should be overriden")
    }

    var didUpdate: Property<[UpdateType]> {
        preconditionFailure("Should be overriden")
    }

    private var _selectedCells: MutableProperty<Set<IndexPath>>
    var selectedCells: Property<Set<IndexPath>> {
        return Property(_selectedCells)
    }

    var numberOfItems: Int {
        preconditionFailure("Should be overriden")
    }

    func cellViewModel(at indexPath: IndexPath) -> CellViewModel {
        preconditionFailure("Should be overriden")
    }

    func loadNextPageIfNeeded() {
        preconditionFailure("Should be overriden")
    }

    func selectRowAtIndexPath(_ indexPath: IndexPath) {
        _selectedCells.value.insert(indexPath)
    }

    func deselectRowAtIndexPath(_ indexPath: IndexPath) {
        _selectedCells.value.remove(indexPath)
    }

    func resetSelection() {
        _selectedCells.value.removeAll()
    }

    init() {
        _selectedCells = MutableProperty(value: [])
    }
}

extension ListViewModel {

    static func model<FetchResult: FetchResultType>(
        fetchResult: FetchResult,
        cellViewModel: @escaping (_ item: FetchResult.FetchObjectType) -> CellViewModel
    ) -> ListViewModel<CellViewModel> {

        return ResultListViewModel<FetchResult, CellViewModel>(fetchResult: fetchResult, cellViewModel: cellViewModel)
    }

}

private class ResultListViewModel <FetchResult: FetchResultType, CellViewModel>: ListViewModel<CellViewModel> {

    typealias CellViewModelMapClosure = (_ item: FetchResult.FetchObjectType) -> CellViewModel

    private let fetchResult: FetchResult
    private let cellViewModelClosure: CellViewModelMapClosure

    init(
        fetchResult: FetchResult,
        cellViewModel: @escaping CellViewModelMapClosure) {

        self.fetchResult = fetchResult
        self.cellViewModelClosure = cellViewModel

        super.init()

        bind(fetchResult: fetchResult)
    }

    override var state: Property<FetchResultState> {
        return fetchResult.state
    }

    override var didUpdate: Property<[UpdateType]> {
        return fetchResult.didUpdate
    }

    override var numberOfItems: Int {
        return fetchResult.numberOfFetchedObjects
    }

    override func cellViewModel(at indexPath: IndexPath) -> CellViewModel {
        let object = fetchResult.object(at: indexPath)
        return cellViewModelClosure(object)
    }

    override func loadNextPageIfNeeded() {
        fetchResult.loadNextPageIfNeeded()
    }

    private func bind(fetchResult: FetchResult) {
        fetchResult.state.observeValues { [weak self] state in
            self?.didStatusUpdate(status: state)
        }
    }

    private func didStatusUpdate(status: FetchResultState) {
        print("[ResultListViewModel] didStatusUpdate \(status)")
    }

}
