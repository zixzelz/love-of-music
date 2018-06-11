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

    var numberOfItems: Int { get }
    func cellViewModel(at indexpath: IndexPath) -> CellViewModel
}

class ListViewModel<CellViewModel>: ListViewModelType {

    var numberOfItems: Int {
        preconditionFailure("Should be overriden")
    }

    func cellViewModel(at indexPath: IndexPath) -> CellViewModel {
        preconditionFailure("Should be overriden")
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
    }

    override var numberOfItems: Int {
        return fetchResult.numberOfFetchedObjects
    }

    override func cellViewModel(at indexPath: IndexPath) -> CellViewModel {
        let object = fetchResult.object(at: indexPath)
        return cellViewModelClosure(object)
    }

    private func bind(fetchResult: FetchResult) {
        fetchResult.state.observeValues { [weak self] state in
            self?.didStatusUpdate(status: state)
        }
    }

    private func didStatusUpdate(status: FetchResultState) {

    }

}
