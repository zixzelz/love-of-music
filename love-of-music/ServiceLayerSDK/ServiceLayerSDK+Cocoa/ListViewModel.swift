//
//  ListViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/8/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result

protocol ListViewModelType {
    associatedtype CellViewModel

    var state: Property<FetchResultState> { get }
    var didUpdate: Signal<[UpdateType], NoError> { get }

    func numberOfSections() -> Int
    func numberOfRows(inSection section: Int) -> Int
    func cellViewModel(at indexpath: IndexPath) -> CellViewModel

    func loadNextPageIfNeeded()

    var selectedCells: Property<Set<IndexPath>> { get }
    func selectRowAtIndexPath(_ indexPath: IndexPath)
    func deselectRowAtIndexPath(_ indexPath: IndexPath)
    func resetSelection()
}

class ListViewModel<CellViewModel>: ListViewModelType {

    let allowsMultipleSelection: Bool

    var state: Property<FetchResultState> {
        preconditionFailure("Should be overriden")
    }

    var didUpdate: Signal<[UpdateType], NoError> {
        preconditionFailure("Should be overriden")
    }

    fileprivate var _selectedCells: MutableProperty<Set<IndexPath>>
    var selectedCells: Property<Set<IndexPath>> {
        return Property(_selectedCells)
    }

    func numberOfSections() -> Int {
        preconditionFailure("Should be overriden")
    }

    func numberOfRows(inSection section: Int) -> Int {
        preconditionFailure("Should be overriden")
    }

    func cellViewModel(at indexPath: IndexPath) -> CellViewModel {
        preconditionFailure("Should be overriden")
    }

    func section(at index: Int) -> String? {
        preconditionFailure("Should be overriden")
    }

    func loadNextPageIfNeeded() {
        preconditionFailure("Should be overriden")
    }

    func selectRowAtIndexPath(_ indexPath: IndexPath) {
        preconditionFailure("Should be overriden")
    }

    func deselectRowAtIndexPath(_ indexPath: IndexPath) {
        preconditionFailure("Should be overriden")
    }

    func resetSelection() {
        preconditionFailure("Should be overriden")
    }

    init(allowsMultipleSelection: Bool = false) {
        _selectedCells = MutableProperty([])
        self.allowsMultipleSelection = allowsMultipleSelection
    }
}

extension ListViewModel {

    static func model<FetchResult: FetchResultType>(
        fetchResult: FetchResult,
        allowsMultipleSelection: Bool = false,
        mapSectionTitle: ((Int) -> String?)? = nil,
        cellViewModel: @escaping (_ item: FetchResult.FetchObjectType) -> CellViewModel
    ) -> ListViewModel<CellViewModel> {

        return ResultListViewModel<FetchResult, CellViewModel>(
            fetchResult: fetchResult,
            allowsMultipleSelection: allowsMultipleSelection,
            mapSectionTitle: mapSectionTitle,
            cellViewModel: cellViewModel
        )
    }

}

private class ResultListViewModel <FetchResult: FetchResultType, CellViewModel>: ListViewModel<CellViewModel> {

    typealias SectionMap = (Int) -> String?
    typealias CellViewModelMapClosure = (_ item: FetchResult.FetchObjectType) -> CellViewModel

    private let fetchResult: FetchResult
    private let cellViewModelClosure: CellViewModelMapClosure
    private let sectionMap: SectionMap?

    private var selectedMap = [IndexPath: FetchResult.FetchObjectType]()
    private var allSelectedObjects: [FetchResult.FetchObjectType] = []

    init(
        fetchResult: FetchResult,
        allowsMultipleSelection: Bool = false,
        mapSectionTitle: SectionMap? = nil,
        cellViewModel: @escaping CellViewModelMapClosure) {

        self.fetchResult = fetchResult
        self.cellViewModelClosure = cellViewModel
        self.sectionMap = mapSectionTitle

        super.init()

        bind(fetchResult: fetchResult)
    }

    override var state: Property<FetchResultState> {
        return fetchResult.state
    }

    override var didUpdate: Signal<[UpdateType], NoError> {
        return fetchResult.didUpdate
    }

    override func numberOfSections() -> Int {
        return fetchResult.numberOfSections()
    }

    override func numberOfRows(inSection section: Int) -> Int {
        return fetchResult.numberOfRows(inSection: section)
    }

    override func cellViewModel(at indexPath: IndexPath) -> CellViewModel {
        let object = fetchResult.object(at: indexPath)
        return cellViewModelClosure(object)
    }

    override func section(at index: Int) -> String? {
        guard let sectionMap = self.sectionMap else {
            return nil
        }
        return sectionMap(index)
    }

    override func loadNextPageIfNeeded() {
        fetchResult.loadNextPageIfNeeded()
    }

    private var scopedDisposable: ScopedDisposable<AnyDisposable>?
    private func bind(fetchResult: FetchResult) {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        list += fetchResult.state.producer.startWithValues() { [weak self] state in
            self?.didStatusUpdate(status: state)
        }

        list += didUpdate.observeValues { [weak self] _ in
            self?.updateSelectionMap()
        }
    }

    override func selectRowAtIndexPath(_ indexPath: IndexPath) {
        guard selectedMap[indexPath] == nil else {
            return
        }

        if !allowsMultipleSelection {
            selectedMap.removeAll()
            allSelectedObjects.removeAll()
        }

        let object = fetchResult.object(at: indexPath)
        allSelectedObjects.append(object)
        selectedMap[indexPath] = object
        updateSelection()
    }

    override func deselectRowAtIndexPath(_ indexPath: IndexPath) {
        allSelectedObjects.remove(at: indexPath.row)
        selectedMap.removeValue(forKey: indexPath)
        updateSelection()
    }

    override func resetSelection() {
        allSelectedObjects.removeAll()
        selectedMap.removeAll()
        updateSelection()
    }

    private func didStatusUpdate(status: FetchResultState) {
        print("[ResultListViewModel] didStatusUpdate \(status)")
    }

    private func updateSelectionMap() {

        var newMap = [IndexPath: FetchResult.FetchObjectType]()
        for object in allSelectedObjects {
            if let newIndexPath = fetchResult.indexPathForObject(object) {
                newMap[newIndexPath] = object
            }
        }
        selectedMap = newMap
        updateSelection()
    }

    private func updateSelection() {
        let selectedIndexPaths = Set(selectedMap.keys)
        if _selectedCells.value != selectedIndexPaths {
            _selectedCells.value = selectedIndexPaths
        }
    }

}
