//
//  TableViewDataSource.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/12/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class TableViewDataSource <CellViewModel>: NSObject, UITableViewDataSource {

    typealias CellMap = (_ tableView: UITableView, _ indexPath: IndexPath, _ cellVM: CellViewModel) -> UITableViewCell
    typealias Paging = (pool: Int, willDisplayCell: Property<IndexPath>)

    private var tableView: UITableView
    private var listViewModel: ListViewModel<CellViewModel>
    private var cellMap: CellMap

    init(
        tableView: UITableView,
        listViewModel: ListViewModel<CellViewModel>,
        paging: Paging? = nil,
        map: @escaping CellMap) {

        self.tableView = tableView
        self.listViewModel = listViewModel
        self.cellMap = map

        super.init()
        bind(listViewModel)

        if let paging = paging {
            bindPaging(paging)
        }
    }

    private var scopedDisposable: ScopedDisposable?
    private func bind(_ listViewModel: ListViewModel<CellViewModel>) {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        list += listViewModel.didUpdate.observeValues { [weak self] in
            self?.tableView.reloadData()
        }
        tableView.reloadData()
    }

    private func bindPaging(_ paging: Paging) {

        let pool = paging.pool
        paging.willDisplayCell.observeValues { [unowned self] (indexPath) in

            if indexPath.row + pool > self.totalCount {
                self.listViewModel.loadNextPageIfNeeded()
            }
        }
    }

    private var totalCount: Int {
        return listViewModel.numberOfItems
    }

    //MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return totalCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellVM = listViewModel.cellViewModel(at: indexPath)
        return cellMap(tableView, indexPath, cellVM)
    }

}
